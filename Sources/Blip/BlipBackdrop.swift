import AppKit
import QuartzCore

/// What the backdrop looks like through the banner: a gaussian blur, then a saturation boost and a
/// linear tone curve (`out = scale * colour + bias`), all done by CoreAnimation backdrop filters so
/// nothing is a plain dark overlay.
final class BackdropBlurView: NSView {
  struct Look: Equatable {
    var radius = 0.0
    var saturation = 1.0
    var scale = 1.0
    /// Added after the scale, as a fraction of full white (0...1).
    var bias = 0.0

    var isIdentity: Bool { self.radius <= 0 && self.saturation == 1 && self.scale == 1 && self.bias == 0 }
  }

  private var backdrop: CALayer?
  /// Opacity of the blur itself. Fading it directly keeps its rounded clip, which fading the view does not.
  var blurFadeDuration: Double = 0.18
  var blurOpacity: Float = 1 { didSet { self.applyOpacity(animated: true) } }

  private func applyOpacity(animated: Bool) {
    guard let backdrop = self.backdrop else { return }
    let from = backdrop.presentation()?.opacity ?? backdrop.opacity
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    backdrop.opacity = self.blurOpacity
    CATransaction.commit()
    if animated {
      let animation = CABasicAnimation(keyPath: "opacity")
      animation.fromValue = from
      animation.toValue = self.blurOpacity
      animation.duration = self.blurFadeDuration
      backdrop.add(animation, forKey: "fade")
    }
  }
  private(set) var look = Look()
  var cornerRadius: CGFloat = 22 { didSet { self.updateFrame() } }
  /// Shrinks the blur away from the banner's edge, in points.
  var inset: CGFloat = 0 { didSet { self.updateFrame() } }

  /// Whether this system has the private CoreAnimation classes the backdrop needs.
  static var isAvailable: Bool {
    NSClassFromString("CABackdropLayer") != nil && NSClassFromString("CAFilter") != nil
  }

  static func makeFilter(type: String) -> NSObject? {
    guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
    return filterClass.perform(NSSelectorFromString("filterWithType:"), with: type)?.takeUnretainedValue() as? NSObject
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func apply(_ look: Look) {
    guard look != self.look || self.backdrop == nil else { return }
    self.look = look
    self.backdrop?.removeFromSuperlayer()
    self.backdrop = nil
    guard !look.isIdentity, Self.isAvailable, let layer = self.layer,
          let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type else { return }
    var filters: [NSObject] = []
    if look.radius > 0, let blur = Self.makeFilter(type: "gaussianBlur") {
      blur.setValue(look.radius, forKey: "inputRadius")
      blur.setValue(true, forKey: "inputNormalizeEdges")
      filters.append(blur)
    }
    if look.saturation != 1, let saturate = Self.makeFilter(type: "colorSaturate") {
      saturate.setValue(look.saturation, forKey: "inputAmount")
      filters.append(saturate)
    }
    if look.scale != 1 || look.bias != 0, let matrix = Self.makeFilter(type: "colorMatrix") {
      let scale = Float(look.scale), bias = Float(look.bias)
      // CAColorMatrix: four rows of (r, g, b, a, constant).
      var values: [Float] = [
        scale, 0, 0, 0, bias,
        0, scale, 0, 0, bias,
        0, 0, scale, 0, bias,
        0, 0, 0, 1, 0,
      ]
      matrix.setValue(NSValue(bytes: &values, objCType: "{CAColorMatrix=ffffffffffffffffffff}"), forKey: "inputColorMatrix")
      filters.append(matrix)
    }
    let backdrop = backdropClass.init()
    backdrop.setValue(true, forKey: "windowServerAware")
    backdrop.filters = filters
    layer.addSublayer(backdrop)
    self.backdrop = backdrop
    self.updateFrame()
    self.applyOpacity(animated: false)
  }

  override func layout() {
    super.layout()
    self.updateFrame()
  }

  private func updateFrame() {
    guard let backdrop = self.backdrop else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let inset = max(0, self.inset)
    backdrop.frame = self.bounds.insetBy(dx: inset, dy: inset)
    backdrop.cornerRadius = max(0, self.cornerRadius - inset)
    backdrop.cornerCurve = .continuous
    backdrop.masksToBounds = true
    CATransaction.commit()
  }
}

/// A thin dark ring along the banner's edge, drawn over the glass to tone down its bright rim
/// highlight. Ignores the mouse.
final class EdgeShadeView: NSView {
  var cornerRadius: CGFloat = 22 { didSet { self.applyRing() } }
  /// 0 draws nothing; 1 is the strongest ring.
  var strength: Double = 0 { didSet { self.applyRing() } }
  private var rings: [CALayer] = []
  private let topBand = CAGradientLayer()
  private let bottomBand = CAGradientLayer()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.wantsLayer = true
    for band in [self.topBand, self.bottomBand] { self.layer?.addSublayer(band) }
    // Three 1 pt rings, each fainter than the one outside it, so the edge fades instead of cutting.
    for _ in 0 ..< 3 {
      let ring = CALayer()
      ring.borderWidth = 1
      ring.cornerCurve = .continuous
      self.layer?.addSublayer(ring)
      self.rings.append(ring)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()
    self.applyRing()
  }

  /// Redraws after the shared style changes.
  func refresh() { self.applyRing() }

  private func applyRing() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let strength = max(0, min(1, self.strength))
    for (index, ring) in self.rings.enumerated() {
      let inset = CGFloat(index)
      let style = BlipChromeStyle.current
      let width = CGFloat(style.edgeWidth)
      ring.borderWidth = width
      ring.frame = self.bounds.insetBy(dx: inset * width, dy: inset * width)
      ring.cornerRadius = max(0, self.cornerRadius - inset * width)
      let alpha = min(1, strength * style.edgeAlpha * [0.35, 0.2, 0.1][index])
      ring.borderColor = NSColor(white: CGFloat(style.edgeBrightness), alpha: CGFloat(alpha)).cgColor
    }
    let style = BlipChromeStyle.current
    let height = CGFloat(style.cancelBandHeight)
    let alpha = CGFloat(min(1, style.cancelBandAlpha * strength))
    let dark = NSColor.black.withAlphaComponent(alpha).cgColor
    let clear = NSColor.black.withAlphaComponent(0).cgColor
    self.topBand.colors = [dark, clear]
    self.topBand.startPoint = CGPoint(x: 0.5, y: 1)
    self.topBand.endPoint = CGPoint(x: 0.5, y: 0)
    self.topBand.frame = CGRect(x: 0, y: self.bounds.height - height, width: self.bounds.width, height: height)
    self.bottomBand.colors = [dark, clear]
    self.bottomBand.startPoint = CGPoint(x: 0.5, y: 0)
    self.bottomBand.endPoint = CGPoint(x: 0.5, y: 1)
    self.bottomBand.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: height)
    for band in [self.topBand, self.bottomBand] {
      let mask = CAShapeLayer()
      mask.path = CGPath(roundedRect: self.bounds.offsetBy(dx: 0, dy: band === self.topBand ? -(self.bounds.height - height) : 0), cornerWidth: self.cornerRadius, cornerHeight: self.cornerRadius, transform: nil)
      band.mask = mask
    }
    CATransaction.commit()
    self.isHidden = (strength <= 0 || style.edgeAlpha <= 0) && alpha <= 0
  }
}


/// The system banner's thin edge light: a bright hairline along the top and bottom edges that fades
/// out toward the sides, with a dim glow just inside it, and a dark hairline along the left and
/// right edges. Measured from the system banner; drawn here instead of relying on the glass's own
/// rim, which is thicker and cannot be tuned. Ignores the mouse.
final class RimView: NSView {
  var cornerRadius: CGFloat = 22 { didSet { self.needsLayout = true } }
  private let whiteLayers = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
  private let darkLayer = CAShapeLayer()
  private let whiteMask = CAGradientLayer()
  private let darkMask = CAGradientLayer()
  private let whiteHost = CALayer()
  private let darkHost = CALayer()
  private let sideHost = CALayer()
  private let sideMask = CAGradientLayer()
  private let glowHost = CALayer()
  private let glowMask = CAShapeLayer()
  private let topGlow = CAGradientLayer()
  private let bottomGlow = CAGradientLayer()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.wantsLayer = true
    self.whiteMask.colors = [NSColor.white.cgColor, NSColor.clear.cgColor, NSColor.clear.cgColor, NSColor.white.cgColor]
    self.whiteMask.locations = [0, 0.3, 0.7, 1]
    self.whiteMask.startPoint = CGPoint(x: 0.5, y: 1)
    self.whiteMask.endPoint = CGPoint(x: 0.5, y: 0)
    self.whiteHost.mask = self.whiteMask
    for layer in self.whiteLayers {
      layer.fillColor = nil
      self.whiteHost.addSublayer(layer)
    }
    self.sideMask.startPoint = CGPoint(x: 0, y: 0.5)
    self.sideMask.endPoint = CGPoint(x: 1, y: 0.5)
    self.sideHost.mask = self.sideMask
    self.sideHost.addSublayer(self.whiteHost)
    self.layer?.addSublayer(self.sideHost)
    self.glowHost.mask = self.glowMask
    for glow in [self.topGlow, self.bottomGlow] { self.glowHost.addSublayer(glow) }
    self.layer?.addSublayer(self.glowHost)
    self.darkMask.colors = [NSColor.white.cgColor, NSColor.clear.cgColor, NSColor.clear.cgColor, NSColor.white.cgColor]
    self.darkMask.locations = [0, 0.1, 0.9, 1]
    self.darkMask.startPoint = CGPoint(x: 0, y: 0.5)
    self.darkMask.endPoint = CGPoint(x: 1, y: 0.5)
    self.darkHost.mask = self.darkMask
    self.darkLayer.fillColor = nil
    self.darkHost.addSublayer(self.darkLayer)
    self.layer?.addSublayer(self.darkHost)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()
    self.refresh()
  }

  func refresh() {
    let style = BlipChromeStyle.current
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let width = CGFloat(style.rimWidth)
    for host in [self.whiteHost, self.darkHost, self.sideHost, self.glowHost] { host.frame = self.bounds }
    let fade = max(0.001, min(0.5, style.rimSideFade))
    self.sideMask.frame = self.bounds
    let floor = NSColor.white.withAlphaComponent(CGFloat(max(0, min(1, style.rimSideFloor)))).cgColor
    self.sideMask.colors = [floor, NSColor.white.cgColor, NSColor.white.cgColor, floor]
    self.sideMask.locations = [0, NSNumber(value: fade), NSNumber(value: 1 - fade), 1]
    let glowHeight = CGFloat(style.innerGlowHeight)
    let glowColor = NSColor.white.withAlphaComponent(CGFloat(style.innerGlowAlpha)).cgColor
    let clear = NSColor.white.withAlphaComponent(0).cgColor
    self.glowMask.frame = self.bounds
    self.glowMask.path = CGPath(roundedRect: self.bounds, cornerWidth: self.cornerRadius, cornerHeight: self.cornerRadius, transform: nil)
    self.topGlow.colors = [glowColor, clear]
    self.topGlow.startPoint = CGPoint(x: 0.5, y: 1)
    self.topGlow.endPoint = CGPoint(x: 0.5, y: 0)
    self.topGlow.frame = CGRect(x: 0, y: self.bounds.height - glowHeight, width: self.bounds.width, height: glowHeight)
    self.bottomGlow.colors = [glowColor, clear]
    self.bottomGlow.startPoint = CGPoint(x: 0.5, y: 0)
    self.bottomGlow.endPoint = CGPoint(x: 0.5, y: 1)
    self.bottomGlow.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: glowHeight)
    self.glowHost.isHidden = glowHeight <= 0 || style.innerGlowAlpha <= 0
    self.whiteMask.frame = self.bounds
    self.darkMask.frame = self.bounds
    func path(inset: CGFloat) -> CGPath {
      let rect = self.bounds.insetBy(dx: inset, dy: inset)
      return CGPath(roundedRect: rect, cornerWidth: max(0, self.cornerRadius - inset), cornerHeight: max(0, self.cornerRadius - inset), transform: nil)
    }
    let alphas = [style.rimWhite, style.rimWhite * style.rimGlow, style.rimWhite * style.rimGlow * 0.5]
    for (index, layer) in self.whiteLayers.enumerated() {
      layer.frame = self.bounds
      layer.lineWidth = width
      layer.path = path(inset: width * (CGFloat(index) + 0.5))
      layer.strokeColor = NSColor.white.withAlphaComponent(CGFloat(alphas[index])).cgColor
    }
    self.darkLayer.frame = self.bounds
    self.darkLayer.lineWidth = width
    self.darkLayer.path = path(inset: width / 2)
    self.darkLayer.strokeColor = NSColor.black.withAlphaComponent(CGFloat(style.rimDark)).cgColor
    CATransaction.commit()
    self.isHidden = style.rimWhite <= 0 && style.rimDark <= 0
  }
}

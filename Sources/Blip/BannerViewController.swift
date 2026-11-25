import AppKit

final class BannerViewController: NSViewController {
  private enum Constants {
    static let cornerRadius: CGFloat = 22
    // Measured against the system banner: 293 x 64 points.
    static let contentInset = NSEdgeInsets(top: 11.5, left: 16.5, bottom: 10, right: 16.5)
    static let titleToSliderGap: CGFloat = 4
    static let trackLeading: CGFloat = 32.75
    /// Distance from the banner's right edge to the end of the track (banner is 293 wide, track ends at 252.5).
    static let trackTrailing: CGFloat = 39.75
    static let leftIconCenterX: CGFloat = 20.75
    static let rightIconCenterXFromTrailing: CGFloat = 24.55
    static let iconDrop: CGFloat = 1.5
    /// The 17 notches are centred 4.75 in from each end of the track, 13.3 apart; with equal cells that is
    /// a container 1.9 wider than the track on each side.
    static let markerOverhang: CGFloat = -1.9
    static let trackHeight: CGFloat = 4.5
    static let barCornerRadius: CGFloat = 2.5
    static let markerCount = 17
    /// Vertical centre of the second row, measured from the top: title top inset + title height +
    /// gap + half the slider height. The subtitle is centred here so it sits where the slider does.
    static let secondRowCenterY: CGFloat = 11.5 + 15 + 4 + (4.5 + 16) / 2
  }

  // Background
  private let contentContainerView = BannerHoverView()
  private var blurView: NSView?
  private var scrimView: NSView?
  private var glassView: NSView?
  private let backdropBlurView = BackdropBlurView()
  private let edgeShadeView = EdgeShadeView()
  private let rimView = RimView()
  private weak var rootBackgroundView: NSView?

  // Shared skeleton: one title, in the same place for every banner
  private let titleLabel = NSTextField(labelWithString: "")

  // Second row, slider flavour
  private let leftIconButton = NSButton()
  private let rightIconButton = NSButton()
  private let levelSlider = BannerSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
  private let markersView = NSStackView()
  private var leftIconWidth: NSLayoutConstraint!
  private var leftIconHeight: NSLayoutConstraint!
  private var rightIconWidth: NSLayoutConstraint!
  private var rightIconHeight: NSLayoutConstraint!

  // Second row, message flavour
  private let detailLabel = NSTextField(labelWithString: "")
  private let messageIconView = NSImageView()
  private var messageIconWidth: NSLayoutConstraint!
  private var messageIconHeight: NSLayoutConstraint!
  private var detailTrailingToIcon: NSLayoutConstraint!
  private var detailTrailingToEdge: NSLayoutConstraint!

  var hoverChanged: ((Bool) -> Void)?
  var closeRequested: (() -> Void)?
  private let closeButton = BannerCloseButton()
  private var showsCloseButton = false
  private var closeLeading, closeTop, closeWidth, closeHeight: NSLayoutConstraint?
  var stepClicked: ((BlipStep) -> Void)?
  var levelChanged: ((Double) -> Void)?
  var tapped: (() -> Void)?

  /// Extra window room past the banner's top-left corner, for the close button.
  static let bleed: CGFloat = 10

  override func loadView() {
    let rootView = NSView()
    rootView.wantsLayer = true
    rootView.layer?.masksToBounds = false

    self.installBackground(in: rootView)
    self.contentContainerView.hoverChanged = { [weak self] hovering in
      self?.hoverChanged?(hovering)
      self?.setCloseButtonVisible(hovering)
    }
    self.contentContainerView.clicked = { [weak self] in self?.tapped?() }

    self.buildSkeleton()
    // Above the glass, not inside it: a backdrop blur inside the glass's content view samples nothing.
    self.buildCloseButton(in: rootView)
    let wrapper = NSView()
    wrapper.addSubview(rootView)
    rootView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      rootView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: Self.bleed),
      rootView.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: Self.bleed),
      rootView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
      rootView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
    ])
    self.view = wrapper
  }

  // MARK: Background

  private func installBackground(in rootView: NSView) {
    if #available(macOS 26.0, *) {
      // Three layers, bottom to top: a real blur (so text stays legible over busy content), a dark
      // scrim, and Liquid Glass whose lensing draws the refracting rim. The glass is not clipped by
      // a mask layer, because that would cut off the rim.
      let blur = NSVisualEffectView()
      blur.material = .hudWindow
      blur.blendingMode = .behindWindow
      blur.state = .active
      blur.wantsLayer = true
      blur.layer?.cornerRadius = Constants.cornerRadius
      blur.layer?.masksToBounds = true
      rootView.addSubview(blur)

      self.backdropBlurView.cornerRadius = Constants.cornerRadius
      rootView.addSubview(self.backdropBlurView)

      let scrim = NSView()
      scrim.wantsLayer = true
      scrim.layer?.cornerRadius = Constants.cornerRadius
      scrim.layer?.masksToBounds = true
      scrim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.24).cgColor
      rootView.addSubview(scrim)

      let glassView = NSGlassEffectView()
      glassView.cornerRadius = Constants.cornerRadius
      glassView.style = .clear
      glassView.tintColor = nil
      glassView.contentView = self.contentContainerView
      rootView.addSubview(glassView)
      self.edgeShadeView.cornerRadius = Constants.cornerRadius
      self.edgeShadeView.isHidden = true
      rootView.addSubview(self.edgeShadeView)
      self.rimView.cornerRadius = Constants.cornerRadius
      rootView.addSubview(self.rimView)

      for view in [blur, self.backdropBlurView, scrim, glassView, self.edgeShadeView, self.rimView] {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
          view.topAnchor.constraint(equalTo: rootView.topAnchor),
          view.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
          view.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
          view.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])
      }
      self.blurView = blur
      self.scrimView = scrim
      self.glassView = glassView
      self.rootBackgroundView = rootView
    } else {
      // Before macOS 26 there is no Liquid Glass; fall back to a dark HUD material.
      let effectView = NSVisualEffectView()
      effectView.material = .hudWindow
      effectView.blendingMode = .behindWindow
      effectView.state = .active
      effectView.wantsLayer = true
      effectView.layer?.cornerRadius = Constants.cornerRadius
      effectView.layer?.masksToBounds = true
      rootView.addSubview(effectView)
      effectView.addSubview(self.contentContainerView)
      effectView.translatesAutoresizingMaskIntoConstraints = false
      self.contentContainerView.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        effectView.topAnchor.constraint(equalTo: rootView.topAnchor),
        effectView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
        effectView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        effectView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        self.contentContainerView.topAnchor.constraint(equalTo: effectView.topAnchor),
        self.contentContainerView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
        self.contentContainerView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
        self.contentContainerView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
      ])
    }
  }

  /// The glass recipe of the system banner, fitted to pixel captures of the real thing over a dark
  /// wallpaper and over colour stripes. The glass view supplies the edge refraction and the blur
  /// (through its `glassBackground` filter, see `applyGlassFilter`); its own edge light is hidden and
  /// RimView draws the system banner's instead.
  static let nativeRecipe = BlipGlassRecipe(regular: true, variant: 11, glassOpacity: 0, blurRadius: 1.95, fill: 1, gleam: 0)

  /// Applies a glass recipe, adapted to the system's Liquid Glass settings.
  ///
  /// Scrim and blur strengths were tuned with the tint slider at its default, 0.5, and scale from
  /// there: a clearer setting lightens the banner, a more tinted one darkens it. Reduce Transparency
  /// replaces the glass with a solid fill. Private variants are only set when the system supports them.
  private func applyGlass(_ recipe: BlipGlassRecipe) {
    guard #available(macOS 26.0, *), let glass = self.glassView as? NSGlassEffectView else { return }
    let appearance = BlipAppearance.current

    if appearance.reducesTransparency {
      self.mountContent(inGlass: false)
      glass.isHidden = true
            self.backdropBlurView.isHidden = true
      self.edgeShadeView.isHidden = true
      self.blurView?.isHidden = true
      self.scrimView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
      return
    }

    // A faded glass would fade the text it holds, so the content is lifted out in that case.
    let style = BlipChromeStyle.current
    let tintNow = style.previewTint >= 0 ? style.previewTint : appearance.glassTintAmount
    let fadeSpan = max(0.001, style.lensFadeEnd - style.lensFadeStart)
    let lens = 1 - max(0, min(1, (tintNow - style.lensFadeStart) / fadeSpan))
    let lensing = max(0, min(1, style.glassLensing)) * lens
    self.mountContent(inGlass: false)
    glass.isHidden = false
    glass.alphaValue = CGFloat(lensing)

    glass.style = style.bannerClear >= 0.5 ? .clear : .regular
    if glass.responds(to: NSSelectorFromString("set_variant:")) {
      glass.setValue(Int(style.bannerVariant.rounded()), forKey: "_variant")
    }

    Self.applyPrivateSwitches(to: glass)
    self.applyGlassFilterWhenReady()

    let tint = tintNow
    let scale = CGFloat(tint / BlipAppearance.defaultGlassTintAmount)
    if let blur = recipe.blur, let effect = self.blurView as? NSVisualEffectView {
      switch blur {
      case .hud: effect.material = .hudWindow
      case .popover: effect.material = .popover
      case .fullScreenUI: effect.material = .fullScreenUI
      }
      effect.isHidden = false
      effect.alphaValue = min(1, 0.5 + CGFloat(tint))
    } else {
      self.blurView?.isHidden = true
    }
    self.edgeShadeView.strength = (1 - max(0, min(1, recipe.gleam))) * lensing
    if recipe.blurRadius != nil || recipe.fill != nil {
      // Fitted to the system banner at the lowest, default and highest Liquid Glass tint: the blur
      // grows with the cube of the tint (about 16 points at the top, 2 at the default, none at the
      // bottom), while the fill (saturation boost, flattened tone curve) barely changes with it.
      let t = max(0, min(1, tint))
      let blurScale = pow(t / BlipAppearance.defaultGlassTintAmount, 3)
      // The glass filter does the blur; whatever the glass no longer covers (when it fades) is blurred here.
      var look = BackdropBlurView.Look(radius: max(0, (recipe.blurRadius ?? 0) * blurScale * (1 - lensing) + style.blurAdjust))
      if let fill = recipe.fill {
        let amount = max(0, fill)
        let saturation = 1.95 + 0.03 * (t - 0.5) + style.fillSaturationAdjust
        let scale = 0.67 - 0.065 * (t - 0.5) + style.fillScaleAdjust
        let bias = 0.145 + 0.032 * (t - 0.5) + style.fillBiasAdjust
        look.saturation = 1 + (saturation - 1) * amount
        look.scale = max(0.1, 1 - (1 - scale) * amount)
        look.bias = bias * amount
      }
      self.blurView?.isHidden = true
      self.backdropBlurView.inset = CGFloat(BlipChromeStyle.current.glassBlurInset)
      self.backdropBlurView.isHidden = look.isIdentity
      self.backdropBlurView.apply(look)
    } else {
      self.backdropBlurView.isHidden = true
    }
    let scrimAlpha = recipe.fill == nil ? min(0.5, CGFloat(recipe.scrim) * scale) : 0
    self.scrimView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(scrimAlpha).cgColor
  }

  /// Cuts a strip off the top and bottom of the glass with a mask, to drop its own shine there.
  override func viewDidLayout() {
    super.viewDidLayout()
    self.applyGlassFilter()
  }

  /// Writes the measured values into the glass view's private `glassBackground` filter (on a
  /// CABackdropLayer deep inside it). Does nothing if the layer is not there.
  /// The glass builds its layers asynchronously the first time it is shown, so the filter values are
  /// written again until its filter layer exists.
  private func applyGlassFilterWhenReady(attempt: Int = 0) {
    guard !self.applyGlassFilter(), attempt < 60 else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in self?.applyGlassFilterWhenReady(attempt: attempt + 1) }
  }

  @discardableResult
  private func applyGlassFilter() -> Bool {
    guard let root = self.glassView?.layer else { return false }
    let style = BlipChromeStyle.current
    let tint = style.previewTint >= 0 ? style.previewTint : BlipAppearance.current.glassTintAmount
    let blurScale = pow(max(0, min(1, tint)) / BlipAppearance.defaultGlassTintAmount, 3)
    let blurOpacity = style.glassFilterBlur > 0 ? 1.0 : 0
    let values: [String: Double] = [
      "inputInnerRefractionAmount": style.glassInnerRefraction,
      "inputInnerRefractionHeight": style.glassInnerRefractionHeight,
      "inputOuterRefractionAmount": style.glassOuterRefraction,
      "inputOuterRefractionHeight": style.glassOuterRefractionHeight,
      "inputBlurRadius": style.glassFilterBlur * blurScale,
      "inputBlurOpacity0": blurOpacity, "inputBlurOpacity1": blurOpacity,
      "inputBlurOpacity2": blurOpacity, "inputBlurOpacity3": blurOpacity,
    ]
    let hideEdgeLight = style.glassHideEdgeLight >= 0.5
    var found = false
    func visit(_ layer: CALayer) {
      if layer.name == "@2" || layer.name == "@3" {
        if layer.isHidden != hideEdgeLight { layer.isHidden = hideEdgeLight }
      }
      if let filters = layer.filters as? [NSObject],
         filters.contains(where: { ($0.value(forKey: "type") as? String) == "glassBackground" }) {
        found = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (key, value) in values {
          let path = "filters.glassBackground.\(key)"
          if (layer.value(forKeyPath: path) as? Double) != value { layer.setValue(value, forKeyPath: path) }
        }
        CATransaction.commit()
      }
      layer.sublayers?.forEach(visit)
    }
    visit(root)
    return found
  }


  /// Sets the glass view's other private switches from the shared style, only where they differ.
  @available(macOS 26.0, *)
  private static func applyPrivateSwitches(to glass: NSGlassEffectView) {
    let style = BlipChromeStyle.current
    let integers: [(String, Double)] = [
      ("_subduedState", style.glassSubdued), ("_scrimState", style.glassScrim),
      ("_contentLensing", style.glassContentLensing), ("_adaptiveAppearance", style.glassAdaptive),
    ]
    for (key, value) in integers where glass.responds(to: NSSelectorFromString("set\(key):")) {
      let wanted = Int(value.rounded())
      if (glass.value(forKey: key) as? Int) != wanted { glass.setValue(wanted, forKey: key) }
    }
    let flags: [(String, Double)] = [
      ("_tintOpacityReduced", style.glassReducedTint), ("_useReducedShadowRadius", style.glassReducedShadow),
      ("_inverseMeshed", style.glassInverseMeshed),
    ]
    for (key, value) in flags where glass.responds(to: NSSelectorFromString("set\(key):")) {
      let wanted = value >= 0.5
      if (glass.value(forKey: key) as? Bool) != wanted { glass.setValue(wanted, forKey: key) }
    }
  }

  /// The text and icons normally live inside the glass view, which hides them whenever the glass is
  /// hidden. For the other backgrounds they are lifted out and pinned over the whole banner.
  private func mountContent(inGlass: Bool) {
    guard #available(macOS 26.0, *), let glass = self.glassView as? NSGlassEffectView,
          let root = self.rootBackgroundView else { return }
    let content = self.contentContainerView
    if inGlass {
      guard glass.contentView !== content else { return }
      content.removeFromSuperview()
      content.translatesAutoresizingMaskIntoConstraints = true
      glass.contentView = content
    } else {
      guard content.superview !== root else { return }
      glass.contentView = nil
      content.removeFromSuperview()
      root.addSubview(content)
      content.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        content.topAnchor.constraint(equalTo: root.topAnchor),
        content.leadingAnchor.constraint(equalTo: root.leadingAnchor),
        content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        content.bottomAnchor.constraint(equalTo: root.bottomAnchor),
      ])
    }
  }

  // MARK: Skeleton

  private func buildSkeleton() {
    let host = self.contentContainerView

    // Title: identical position for every banner.
    self.titleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
    self.titleLabel.textColor = NSColor.white.withAlphaComponent(0.94)
    self.titleLabel.lineBreakMode = .byTruncatingTail
    host.addSubview(self.titleLabel)
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.titleLabel.topAnchor.constraint(equalTo: host.topAnchor, constant: Constants.contentInset.top),
      self.titleLabel.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: Constants.contentInset.left),
      self.titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -Constants.contentInset.right),
    ])

    self.buildSliderRow(in: host)
    self.buildMessageRow(in: host)
  }

  /// The system's banners show a round close button at the top-left corner while the pointer is over
  /// them. It is only added for interactive banners, since the others do not receive the mouse.
  private func buildCloseButton(in host: NSView) {
    self.closeButton.setShown(false, animated: false)
    self.closeButton.onClick = { [weak self] in self?.closeRequested?() }
    self.closeButton.pointerChanged = { [weak self] inside in if !inside { self?.setCloseButtonVisible(false) } }
    host.addSubview(self.closeButton)
    self.closeButton.translatesAutoresizingMaskIntoConstraints = false
    self.closeLeading = self.closeButton.leadingAnchor.constraint(equalTo: host.leadingAnchor)
    self.closeTop = self.closeButton.topAnchor.constraint(equalTo: host.topAnchor)
    self.closeWidth = self.closeButton.widthAnchor.constraint(equalToConstant: 18)
    self.closeHeight = self.closeButton.heightAnchor.constraint(equalToConstant: 18)
    NSLayoutConstraint.activate([self.closeLeading, self.closeTop, self.closeWidth, self.closeHeight].compactMap { $0 })
    self.applyChromeStyle()
    NotificationCenter.default.addObserver(forName: .blipChromeStyleChanged, object: nil, queue: .main) { [weak self] _ in
      self?.applyChromeStyle()
      self?.applyGlass(Self.nativeRecipe)
    }
  }

  private func applyChromeStyle() {
    let style = BlipChromeStyle.current
    self.closeLeading?.constant = -CGFloat(style.closeOutset)
    self.closeTop?.constant = -CGFloat(style.closeOutset)
    self.closeWidth?.constant = CGFloat(style.closeSize)
    self.closeHeight?.constant = CGFloat(style.closeSize)
    self.rimView.cornerRadius = Constants.cornerRadius
    self.closeButton.applyStyle(style)
    self.backdropBlurView.inset = CGFloat(style.glassBlurInset)
    self.edgeShadeView.refresh()
    self.rimView.refresh()
    self.levelSlider.needsDisplay = true
    if self.showsCloseButton { self.setCloseButtonVisible(style.pinPreview) }
    self.levelSlider.setPinned(style.pinPreview)
  }

  private func setCloseButtonVisible(_ visible: Bool) {
    let visible = visible || self.closeButton.isPointerInside || BlipChromeStyle.current.pinPreview
    guard self.showsCloseButton || !visible else { return }
    self.closeButton.setShown(visible)
  }

  private func buildSliderRow(in host: NSView) {
    self.configureIconButton(self.leftIconButton, alpha: 1)
    self.configureIconButton(self.rightIconButton, alpha: 1)
    self.leftIconButton.target = self
    self.leftIconButton.action = #selector(self.handleDecrementClick)
    self.rightIconButton.target = self
    self.rightIconButton.action = #selector(self.handleIncrementClick)
    host.addSubview(self.leftIconButton)
    host.addSubview(self.rightIconButton)

    self.leftIconWidth = self.leftIconButton.widthAnchor.constraint(equalToConstant: 19)
    self.leftIconHeight = self.leftIconButton.heightAnchor.constraint(equalToConstant: 19)
    self.rightIconWidth = self.rightIconButton.widthAnchor.constraint(equalToConstant: 20)
    self.rightIconHeight = self.rightIconButton.heightAnchor.constraint(equalToConstant: 20)
    // Positions measured against the system banner (points from its left edge): the track runs from
    // 30.5 to 252.5, the icons are centred at 19.5 and 267.7, and the icons sit about 1.5 below the track.
    self.configureSlider()
    host.addSubview(self.levelSlider)
    self.levelSlider.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.levelSlider.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: Constants.trackLeading),
      self.levelSlider.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -Constants.trackTrailing),
      self.levelSlider.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: Constants.titleToSliderGap),
      self.levelSlider.heightAnchor.constraint(equalToConstant: Constants.trackHeight + 16),
      self.leftIconButton.centerXAnchor.constraint(equalTo: host.leadingAnchor, constant: Constants.leftIconCenterX),
      self.rightIconButton.centerXAnchor.constraint(equalTo: host.trailingAnchor, constant: -Constants.rightIconCenterXFromTrailing),
      self.leftIconButton.centerYAnchor.constraint(equalTo: self.levelSlider.centerYAnchor, constant: Constants.iconDrop),
      self.rightIconButton.centerYAnchor.constraint(equalTo: self.levelSlider.centerYAnchor, constant: Constants.iconDrop),
      self.leftIconWidth, self.leftIconHeight, self.rightIconWidth, self.rightIconHeight,
    ])

    self.markersView.orientation = .horizontal
    self.markersView.alignment = .centerY
    self.markersView.distribution = .fillEqually
    self.markersView.spacing = 0
    host.addSubview(self.markersView)
    self.markersView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.markersView.leadingAnchor.constraint(equalTo: self.levelSlider.leadingAnchor, constant: Constants.markerOverhang),
      self.markersView.trailingAnchor.constraint(equalTo: self.levelSlider.trailingAnchor, constant: -Constants.markerOverhang),
      self.markersView.topAnchor.constraint(equalTo: self.levelSlider.centerYAnchor, constant: (Constants.trackHeight / 2) + 2),
      self.markersView.heightAnchor.constraint(equalToConstant: 3),
    ])

    for _ in 0 ..< Constants.markerCount {
      let markerContainer = NSView()
      markerContainer.translatesAutoresizingMaskIntoConstraints = false
      let marker = NSView()
      marker.wantsLayer = true
      marker.layer?.cornerRadius = 1.1
      marker.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
      marker.translatesAutoresizingMaskIntoConstraints = false
      markerContainer.addSubview(marker)
      NSLayoutConstraint.activate([
        marker.centerXAnchor.constraint(equalTo: markerContainer.centerXAnchor),
        marker.centerYAnchor.constraint(equalTo: markerContainer.centerYAnchor),
        marker.widthAnchor.constraint(equalToConstant: 2.2),
        marker.heightAnchor.constraint(equalToConstant: 2.2),
      ])
      self.markersView.addArrangedSubview(markerContainer)
    }
  }

  private func buildMessageRow(in host: NSView) {
    // The subtitle starts at the title's left edge and is centred on the row the slider uses.
    self.detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
    self.detailLabel.textColor = NSColor.white.withAlphaComponent(0.7)
    self.detailLabel.lineBreakMode = .byTruncatingTail
    host.addSubview(self.detailLabel)
    self.detailLabel.translatesAutoresizingMaskIntoConstraints = false

    self.messageIconView.imageScaling = .scaleProportionallyUpOrDown
    self.messageIconView.contentTintColor = .white
    self.messageIconView.translatesAutoresizingMaskIntoConstraints = false
    host.addSubview(self.messageIconView)

    self.messageIconWidth = self.messageIconView.widthAnchor.constraint(equalToConstant: 26)
    self.messageIconHeight = self.messageIconView.heightAnchor.constraint(equalToConstant: 26)
    self.detailTrailingToIcon = self.detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.messageIconView.leadingAnchor, constant: -8)
    self.detailTrailingToEdge = self.detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -Constants.contentInset.right)
    NSLayoutConstraint.activate([
      self.detailLabel.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: Constants.contentInset.left),
      self.detailLabel.centerYAnchor.constraint(equalTo: host.topAnchor, constant: Constants.secondRowCenterY),
      self.messageIconView.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -Constants.contentInset.right),
      self.messageIconView.centerYAnchor.constraint(equalTo: host.centerYAnchor),
      self.messageIconWidth, self.messageIconHeight,
      self.detailTrailingToIcon,
    ])
  }

  // MARK: Updating

  /// Fills the views from `content`.
  func apply(_ content: BlipContent) {
    _ = self.view
    self.applyGlass(Self.nativeRecipe)
    self.showsCloseButton = content.isInteractive
    if !content.isInteractive {
      self.closeButton.setShown(false, animated: false)
    }
    self.titleLabel.stringValue = content.title
    self.titleLabel.isHidden = content.title.isEmpty

    let isSlider = content.layout == .slider
    self.leftIconButton.isHidden = !isSlider || content.leadingIcon == nil
    self.rightIconButton.isHidden = !isSlider || content.trailingIcon == nil
    self.levelSlider.isHidden = !isSlider
    self.levelSlider.setPinned(isSlider && BlipChromeStyle.current.pinPreview)
    self.markersView.isHidden = !isSlider || !content.showsMarkers
    self.detailLabel.isHidden = isSlider || (content.message ?? "").isEmpty
    let showsMessageIcon = !isSlider && content.messageIconPlacement == .trailing && content.leadingIcon != nil
    self.messageIconView.isHidden = !showsMessageIcon

    if isSlider {
      self.leftIconButton.image = content.leadingIcon?.makeImage()
      self.rightIconButton.image = content.trailingIcon?.makeImage()
      self.leftIconWidth.constant = content.leadingIconSize
      self.leftIconHeight.constant = content.leadingIconSize
      self.rightIconWidth.constant = content.trailingIconSize
      self.rightIconHeight.constant = content.trailingIconSize
      // Always enabled: a disabled control draws grey. Non-interactive banners ignore the mouse anyway.
      self.leftIconButton.isEnabled = true
      self.rightIconButton.isEnabled = true
      self.levelSlider.isEnabled = true
      self.update(level: content.level)
    } else {
      self.detailLabel.stringValue = content.message ?? ""
      self.messageIconView.image = content.leadingIcon?.makeImage(pointSize: content.leadingIconSize * 0.8, weight: .regular)
      self.messageIconWidth.constant = content.leadingIconSize
      self.messageIconHeight.constant = content.leadingIconSize
      self.detailTrailingToIcon.isActive = showsMessageIcon
      self.detailTrailingToEdge.isActive = !showsMessageIcon
    }
  }

  func update(level: Double) {
    self.levelSlider.doubleValue = max(0, min(1, level))
  }

  /// Sets how far the banner is into its appearance, 0 (hidden) to 1 (shown): it grows from, and
  /// shrinks back to, a slightly smaller size pinned at its top centre.
  func setAppearance(_ progress: CGFloat) {
    guard let layer = self.view.layer else { return }
    let style = BlipChromeStyle.current
    let bounds = self.view.bounds
    let bleed = Self.bleed
    let anchor = CGPoint(x: bleed + (bounds.width - bleed) / 2, y: bounds.height - bleed)
    let sx = CGFloat(style.animScaleX) + (1 - CGFloat(style.animScaleX)) * progress
    let sy = CGFloat(style.animScaleY) + (1 - CGFloat(style.animScaleY)) * progress
    var t = CATransform3DMakeTranslation(anchor.x, anchor.y, 0)
    t = CATransform3DScale(t, sx, sy, 1)
    t = CATransform3DTranslate(t, -anchor.x, -anchor.y, 0)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.sublayerTransform = t
    CATransaction.commit()
  }

  // MARK: Helpers

  private func configureIconButton(_ button: NSButton, alpha: CGFloat) {
    button.contentTintColor = .white
    button.isBordered = false
    button.bezelStyle = .regularSquare
    button.focusRingType = .none
    button.imagePosition = .imageOnly
    button.imageScaling = .scaleProportionallyDown
    button.translatesAutoresizingMaskIntoConstraints = false
    button.alphaValue = alpha
  }

  private func configureSlider() {
    let sliderCell = BannerSliderCell()
    sliderCell.controlSize = .small
    sliderCell.isContinuous = true
    sliderCell.trackFillColor = NSColor.white
    sliderCell.trackEmptyColor = NSColor.white.withAlphaComponent(0.2)
    sliderCell.trackCornerRadius = Constants.barCornerRadius
    sliderCell.trackHeight = Constants.trackHeight
    sliderCell.knobColor = NSColor.white.withAlphaComponent(0.94)
    self.levelSlider.cell = sliderCell
    self.levelSlider.minValue = 0
    self.levelSlider.maxValue = 1
    self.levelSlider.numberOfTickMarks = 0
    self.levelSlider.allowsTickMarkValuesOnly = false
    self.levelSlider.target = self
    self.levelSlider.action = #selector(self.handleSliderChanged(_:))
    self.levelSlider.isContinuous = true
    self.levelSlider.wantsLayer = true
    self.levelSlider.layer?.shadowOpacity = 0
    self.levelSlider.layer?.shadowRadius = 0
    self.levelSlider.focusRingType = .none
  }

  @objc private func handleDecrementClick() { self.stepClicked?(.decrease) }
  @objc private func handleIncrementClick() { self.stepClicked?(.increase) }
  @objc private func handleSliderChanged(_ sender: NSSlider) { self.levelChanged?(sender.doubleValue) }
}

// MARK: - Views

final class BannerHoverView: NSView {
  var hoverChanged: ((Bool) -> Void)?
  var clicked: (() -> Void)?
  private var trackingArea: NSTrackingArea?

  override func updateTrackingAreas() {
    if let trackingArea { self.removeTrackingArea(trackingArea) }
    let trackingArea = NSTrackingArea(
      rect: self.bounds,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    self.addTrackingArea(trackingArea)
    self.trackingArea = trackingArea
    super.updateTrackingAreas()
  }

  override func mouseEntered(with event: NSEvent) { self.hoverChanged?(true) }
  override func mouseExited(with event: NSEvent) { self.hoverChanged?(false) }
  override func mouseUp(with event: NSEvent) { self.clicked?() }
  override func mouseDown(with event: NSEvent) {}
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class BannerSlider: NSSlider {
  private var trackingArea: NSTrackingArea?
  private var knobGlass: NSView?
  private var shadowView: NSView?

  /// Casts the held knob's shadow from a view in the banner itself, since the slider clips its own
  /// drawing. Only the part outside the pill shows.
  private func updateKnobShadow(visible: Bool, rect: NSRect?) {
    guard let host = self.superview else { return }
    if self.shadowView == nil {
      let view = NSView()
      view.wantsLayer = true
      view.layer?.masksToBounds = false
      view.layer?.shadowColor = NSColor.black.cgColor
      view.layer?.mask = CAShapeLayer()
      let ring = CAShapeLayer()
      ring.fillColor = nil
      ring.lineWidth = 2
      view.layer?.addSublayer(ring)
      self.shadowView = view
    }
    guard let view = self.shadowView, let layer = view.layer else { return }
    if view.superview !== host { host.addSubview(view, positioned: .above, relativeTo: self) }
    view.isHidden = !visible || self.isHiddenOrHasHiddenAncestor
    guard visible, !self.isHiddenOrHasHiddenAncestor, let rect else { return }
    let style = BlipChromeStyle.current
    let pad: CGFloat = 60
    let inHost = self.convert(rect, to: host)
    view.frame = inHost.insetBy(dx: -pad, dy: -pad)
    let pill = CGPath(roundedRect: NSRect(x: pad, y: pad, width: inHost.width, height: inHost.height),
                      cornerWidth: inHost.height / 2, cornerHeight: inHost.height / 2, transform: nil)
    let inset = CGFloat(style.knobDragShadowInset)
    let narrow = CGPath(roundedRect: NSRect(x: pad + inset, y: pad, width: max(1, inHost.width - 2 * inset), height: inHost.height),
                        cornerWidth: inHost.height / 2, cornerHeight: inHost.height / 2, transform: nil)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.shadowPath = narrow
    if let ring = view.layer?.sublayers?.first as? CAShapeLayer {
      ring.frame = CGRect(origin: .zero, size: view.frame.size)
      ring.path = pill
      ring.strokeColor = NSColor.black.withAlphaComponent(style.knobDragRim).cgColor
    }
    layer.shadowOpacity = Float(style.knobDragShadow)
    layer.shadowRadius = CGFloat(style.knobDragShadowBlur)
    layer.shadowOffset = CGSize(width: 0, height: -CGFloat(style.knobDragShadowOffset))
    let outside = CGMutablePath()
    outside.addRect(CGRect(origin: .zero, size: view.frame.size))
    outside.addPath(pill)
    if let mask = layer.mask as? CAShapeLayer {
      mask.frame = CGRect(origin: .zero, size: view.frame.size)
      mask.path = outside
      mask.fillRule = .evenOdd
    }
    CATransaction.commit()
  }

  /// While the knob is held the system draws it as a small piece of the same glass as the banner,
  /// so it refracts what is behind it. Placed over the knob and moved as it drags.
  fileprivate func setKnobGlass(visible: Bool, rect: NSRect? = nil) {
    guard #available(macOS 26.0, *) else { return }
    if self.knobGlass == nil {
      let glass = KnobGlassView()
      glass.cornerRadius = 9
      glass.style = .regular
      glass.tintColor = nil
      if glass.responds(to: NSSelectorFromString("set_variant:")) { glass.setValue(11, forKey: "_variant") }
      self.addSubview(glass)
      self.knobGlass = glass
    }
    let style = BlipChromeStyle.current
    let visible = visible && !self.isHiddenOrHasHiddenAncestor
    self.knobGlass?.isHidden = !visible
    if let glass = self.knobGlass as? NSGlassEffectView, #available(macOS 26.0, *) { glass.style = style.knobGlassClear >= 0.5 ? .clear : .regular }
    self.knobGlass?.alphaValue = CGFloat(style.knobGlassAlpha)
    if let glass = self.knobGlass as? NSObject, glass.responds(to: NSSelectorFromString("set_variant:")) {
      glass.setValue(Int(style.knobGlassVariant), forKey: "_variant")
    }
    self.updateKnobShadow(visible: visible, rect: rect)
    if let rect, self.knobGlass?.frame != rect { self.knobGlass?.frame = rect }
    if let glass = self.knobGlass as? NSGlassEffectView, #available(macOS 26.0, *), let rect { glass.cornerRadius = rect.height / 2 }
  }

  /// Shows the held look without a press, for comparing it with the system's.
  func setPinned(_ pinned: Bool) {
    guard let cell = self.cell as? BannerSliderCell else { return }
    cell.isHeldForGlass = pinned
    self.needsDisplay = true
    DispatchQueue.main.async { [weak self] in
      guard let self, let cell = self.cell as? BannerSliderCell else { return }
      self.setKnobGlass(visible: pinned, rect: pinned ? cell.pillRect(for: cell.knobRect(flipped: self.isFlipped)) : nil)
    }
  }

  override func mouseDown(with event: NSEvent) {
    guard let cell = self.cell as? BannerSliderCell else { return super.mouseDown(with: event) }
    cell.isHeldForGlass = true
    self.setKnobGlass(visible: true, rect: cell.pillRect(for: cell.knobRect(flipped: self.isFlipped)))
    cell.onKnobMoved = { [weak self] rect in self?.setKnobGlass(visible: true, rect: rect) }
    super.mouseDown(with: event)
    cell.onKnobMoved = nil
    cell.isHeldForGlass = BlipChromeStyle.current.pinPreview
    self.setKnobGlass(visible: BlipChromeStyle.current.pinPreview, rect: cell.pillRect(for: cell.knobRect(flipped: self.isFlipped)))
    self.needsDisplay = true
  }

  override func updateTrackingAreas() {
    if let trackingArea { self.removeTrackingArea(trackingArea) }
    let trackingArea = NSTrackingArea(
      rect: self.bounds,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    self.addTrackingArea(trackingArea)
    self.trackingArea = trackingArea
    super.updateTrackingAreas()
  }

  override func mouseEntered(with event: NSEvent) {
    if let cell = self.cell as? BannerSliderCell {
      cell.isHovering = true
      self.needsDisplay = true
    }
  }

  override func mouseExited(with event: NSEvent) {
    if let cell = self.cell as? BannerSliderCell {
      cell.isHovering = false
      self.needsDisplay = true
    }
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@available(macOS 26.0, *)
private final class KnobGlassView: NSGlassEffectView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class BannerSliderCell: NSSliderCell {
  var onKnobMoved: ((NSRect) -> Void)?

  func pillRect(for knobRect: NSRect) -> NSRect {
    let style = BlipChromeStyle.current
    let held = self.isHighlighted || self.isHeldForGlass
    let width = held ? CGFloat(style.knobHeldWidth) : 18.5, height = held ? CGFloat(style.knobHeldHeight) : 13.5
    return NSRect(x: knobRect.midX - width / 2, y: knobRect.midY - height / 2, width: width, height: height)
  }
  /// True from the mouse press, before the cell reports itself highlighted.
  var isHeldForGlass = false
  var isHovering = false
  var trackFillColor = NSColor.white.withAlphaComponent(0.94)
  var trackEmptyColor = NSColor.white.withAlphaComponent(0.2)
  var trackCornerRadius: CGFloat = 2.5
  var trackHeight: CGFloat = 4.5
  var knobColor = NSColor.white

  override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView?) {
    self.drawBar(inside: cellFrame, flipped: false)
    self.drawKnob(self.knobRect(flipped: false))
  }

  override func drawBar(inside aRect: NSRect, flipped: Bool) {
    let trackRect = self.customTrackRect(from: aRect)
    let roundedRect = NSBezierPath(roundedRect: trackRect, xRadius: self.trackCornerRadius, yRadius: self.trackCornerRadius)
    self.trackEmptyColor.setFill()
    roundedRect.fill()

    var fillRect = trackRect
    let progress = (self.doubleValue - self.minValue) / (self.maxValue - self.minValue)
    fillRect.size.width = trackRect.size.width * CGFloat(progress)
    if fillRect.size.width > 0 {
      let roundedFillRect = NSBezierPath(roundedRect: fillRect, xRadius: self.trackCornerRadius, yRadius: self.trackCornerRadius)
      self.trackFillColor.setFill()
      roundedFillRect.fill()
    }
  }

  // The system's knob is a soft pill, 18.5 x 13.5 points, with a shadow. It is fairly solid while
  // the pointer hovers and turns translucent while it is dragged.
  override var knobThickness: CGFloat { 18.5 }

  override func drawKnob(_ knobRect: NSRect) {
    guard self.isHovering || self.isHighlighted else { return }
    let rect = self.pillRect(for: knobRect)
    let pill = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
    let style = BlipChromeStyle.current
    let held = self.isHighlighted || self.isHeldForGlass
    if held {
      self.onKnobMoved?(rect)
      return
    }
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(style.knobShadow)
    shadow.shadowBlurRadius = style.knobShadowBlur
    shadow.shadowOffset = NSSize(width: 0, height: -1.5)
    shadow.set()
    self.knobColor.withAlphaComponent(max(style.knobAlpha, 0.02)).setFill()
    pill.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.3).setStroke()
    pill.lineWidth = 0.5
    pill.stroke()
  }

  private func customTrackRect(from bounds: NSRect) -> NSRect {
    var rect = bounds
    rect.origin.y = bounds.midY - (self.trackHeight / 2)
    rect.size.height = self.trackHeight
    return rect
  }
}

/// The round close button the system shows at a banner's top-left corner on hover: a blurred,
/// translucent red-orange disc with a thin rim and a soft shadow. Built from stacked views, so the
/// order (blur, tint, cross) is fixed.
final class BannerCloseButton: NSView {
  var onClick: (() -> Void)?
  var pointerChanged: ((Bool) -> Void)?
  private(set) var isPointerInside = false
  private let blur = BackdropBlurView()
  private var glassDisc: NSView?
  private let tint = NSView()
  private let crossView = NSView()
  private let cross = CAShapeLayer()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.wantsLayer = true
    self.layer?.masksToBounds = false
    self.layer?.shadowColor = NSColor.black.cgColor
    self.layer?.shadowRadius = 4
    self.layer?.shadowOffset = .zero

    self.blur.cornerRadius = 9
    self.addSubview(self.blur)

    self.tint.wantsLayer = true
    self.addSubview(self.tint)

    self.crossView.wantsLayer = true
    self.cross.lineCap = .round
    self.cross.fillColor = nil
    self.crossView.layer?.addSublayer(self.cross)
    self.addSubview(self.crossView)
    self.applyStyle(BlipChromeStyle.current)
  }

  private var style = BlipChromeStyle()

  private var shown = false

  /// Fades only the tint, cross and shadow. The blur is switched on and off outright, because
  /// fading a view that holds a backdrop layer makes it render without its rounded clip.
  func setShown(_ shown: Bool, animated: Bool = true) {
    self.shown = shown
    if shown { self.isHidden = false }
    self.blur.blurFadeDuration = self.style.closeFade
    self.blur.blurOpacity = shown && self.style.closeGlass < 0.5 ? 1 : 0
    let target: CGFloat = shown ? 1 : 0
    let apply = {
      self.tint.animator().alphaValue = self.style.closeGlass < 0.5 ? target : 0
      self.crossView.animator().alphaValue = target
      self.glassDisc?.animator().alphaValue = self.style.closeGlass >= 0.5 ? target : 0
    }
    if animated {
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = self.style.closeFade
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        apply()
      }, completionHandler: { [weak self] in
        if let self, !self.shown { self.isHidden = true }
      })
    } else {
      self.tint.alphaValue = self.style.closeGlass < 0.5 ? target : 0
      self.crossView.alphaValue = target
      self.glassDisc?.alphaValue = self.style.closeGlass >= 0.5 ? target : 0
      if !shown { self.isHidden = true }
    }
    self.layer?.shadowOpacity = shown ? Float(self.style.closeShadow) : 0
  }

  func applyStyle(_ style: BlipChromeStyle) {
    self.style = style
    self.layer?.shadowOpacity = self.shown ? Float(style.closeShadow) : 0
    self.blur.apply(.init(radius: style.closeBlur, saturation: 1.4))
    self.tint.layer?.backgroundColor = NSColor(srgbRed: style.closeTintRed / 255, green: style.closeTintGreen / 255, blue: style.closeTintBlue / 255, alpha: style.closeTintAlpha).cgColor
    self.tint.layer?.borderColor = NSColor(srgbRed: style.closeRimRed / 255, green: style.closeRimGreen / 255, blue: style.closeRimBlue / 255, alpha: style.closeRimAlpha).cgColor
    self.tint.layer?.borderWidth = style.closeRimWidth
    if #available(macOS 26.0, *) {
      if self.glassDisc == nil {
        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.alphaValue = 0
        self.addSubview(glass, positioned: .below, relativeTo: self.crossView)
        self.glassDisc = glass
      }
      if let glass = self.glassDisc as? NSGlassEffectView {
        glass.tintColor = NSColor(srgbRed: style.closeTintRed / 255, green: style.closeTintGreen / 255, blue: style.closeTintBlue / 255, alpha: style.closeTintAlpha)
        glass.cornerRadius = self.bounds.width / 2
        glass.frame = self.bounds
        glass.alphaValue = self.shown && style.closeGlass >= 0.5 ? 1 : 0
      }
    }
    self.tint.alphaValue = self.shown && style.closeGlass < 0.5 ? 1 : 0
    self.blur.blurOpacity = self.shown && style.closeGlass < 0.5 ? 1 : 0
    self.cross.strokeColor = NSColor.white.withAlphaComponent(style.closeCrossAlpha).cgColor
    self.cross.lineWidth = style.closeCrossWidth
    self.needsLayout = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layout() {
    super.layout()
    for view in [self.blur, self.tint, self.crossView, self.glassDisc].compactMap({ $0 }) { view.frame = self.bounds }
    if #available(macOS 26.0, *), let glass = self.glassDisc as? NSGlassEffectView { glass.cornerRadius = self.bounds.width / 2 }
    self.tint.layer?.cornerRadius = self.bounds.width / 2
    self.blur.cornerRadius = self.bounds.width / 2
    self.layer?.shadowPath = CGPath(ellipseIn: self.bounds, transform: nil)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let inset = self.bounds.width * CGFloat(self.style.closeCrossInset)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: inset, y: inset))
    path.addLine(to: CGPoint(x: self.bounds.maxX - inset, y: self.bounds.maxY - inset))
    path.move(to: CGPoint(x: inset, y: self.bounds.maxY - inset))
    path.addLine(to: CGPoint(x: self.bounds.maxX - inset, y: inset))
    self.cross.frame = self.bounds
    self.cross.path = path
    CATransaction.commit()
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    self.bounds.contains(self.convert(point, from: self.superview)) ? self : nil
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    for area in self.trackingAreas { self.removeTrackingArea(area) }
    self.addTrackingArea(NSTrackingArea(rect: self.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
  }

  override func mouseEntered(with event: NSEvent) { self.isPointerInside = true; self.pointerChanged?(true) }
  override func mouseExited(with event: NSEvent) { self.isPointerInside = false; self.pointerChanged?(false) }

  override func mouseDown(with event: NSEvent) {}
  override func mouseUp(with event: NSEvent) {
    if self.bounds.contains(self.convert(event.locationInWindow, from: nil)) { self.onClick?() }
  }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

import AppKit

final class BannerPanel: NSPanel {
  private enum Constants {
    static let height: CGFloat = 64
    static let topInset: CGFloat = 10
    static let trailingInset: CGFloat = 34.161
  }

  let displayID: CGDirectDisplayID
  private let bannerViewController = BannerViewController()
  private var content = BlipContent()
  private var handlers = BlipHandlers()
  private var baseFrame: NSRect = .zero
  private var hasPresented = false
  private var isHovered = false
  private var fadeTimer: Timer?
  private var dismissToken = 0
  var didDismiss: (() -> Void)?

  init(displayID: CGDirectDisplayID) {
    self.displayID = displayID
    super.init(
      contentRect: NSRect(origin: .zero, size: NSSize(width: 293, height: Constants.height)),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    self.isReleasedWhenClosed = false
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = false
    self.level = .statusBar
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient, .stationary]
    self.hidesOnDeactivate = false
    self.isMovable = false
    self.isMovableByWindowBackground = false
    self.contentViewController = self.bannerViewController
    self.animationBehavior = .none

    self.bannerViewController.hoverChanged = { [weak self] hovering in self?.hoverStateDidChange(hovering) }
    self.bannerViewController.stepClicked = { [weak self] step in self?.handlers.onStep?(step) }
    self.bannerViewController.levelChanged = { [weak self] level in self?.handlers.onLevelChange?(level) }
    self.bannerViewController.tapped = { [weak self] in self?.handlers.onTap?() }
    self.bannerViewController.closeRequested = { [weak self] in self?.dismiss(reason: .closeButton) }

    self.alphaValue = 0
    self.orderOut(nil)
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  /// Where the banner starts and ends its slide, relative to its resting place.
  private func hiddenOffset() -> (dx: CGFloat, dy: CGFloat) {
    let style = BlipChromeStyle.current
    let d = CGFloat(style.animDistance)
    switch Int(style.animDirection.rounded()) {
    case 1: return (0, -d)
    case 2: return (-d, 0)
    case 3: return (d, 0)
    default: return (0, d)
    }
  }

  // MARK: Presenting

  /// Shows (or updates) the banner with new content.
  func present(_ content: BlipContent, handlers: BlipHandlers) {
    self.content = content
    self.handlers = handlers
    self.ignoresMouseEvents = !content.isInteractive
    self.bannerViewController.apply(content)

    self.fadeTimer?.invalidate()
    self.fadeTimer = nil
    self.dismissToken += 1

    self.baseFrame = self.targetFrame()
    if self.isVisible, self.progress >= 0.999 {
      self.setFrame(self.baseFrame, display: true)
      self.orderFrontRegardless()
    } else {
      if !self.isVisible { self.progress = 0 }
      self.applyProgress()
      self.orderFrontRegardless()
      self.runSpring(to: 1) {}
      self.hasPresented = true
    }

    if !self.isHovered { self.scheduleFade() }
  }

  /// Redraws with the current system appearance, for a banner that is already on screen.
  func reapplyAppearance() {
    guard self.isVisible else { return }
    self.bannerViewController.apply(self.content)
  }

  /// Moves the slider without touching the fade timer (used while the user drags).
  func update(level: Double) {
    self.content.level = level
    self.bannerViewController.update(level: level)
  }

  func dismiss(reason: BlipDismissReason, animated: Bool = true) {
    self.fadeTimer?.invalidate()
    self.fadeTimer = nil
    guard self.isVisible else { return }

    let token = self.dismissToken
    let finish = { [weak self] in
      guard let self, token == self.dismissToken else { return }
      self.orderOut(nil)
      self.setFrame(self.baseFrame, display: false)
      let onDismiss = self.handlers.onDismiss
      self.handlers = BlipHandlers()
      onDismiss?(reason)
      self.didDismiss?()
    }

    guard animated else {
      finish()
      return
    }

    self.runSpring(to: 0) { finish() }
  }

  // MARK: Spring

  private var progress: CGFloat = 0
  private var springTimer: Timer?

  /// Frame, opacity and size for the current progress (0 hidden, 1 shown).
  private func applyProgress() {
    let style = BlipChromeStyle.current
    let hidden = self.hiddenOffset()
    let remaining = 1 - self.progress
    self.setFrame(self.baseFrame.offsetBy(dx: hidden.dx * remaining, dy: hidden.dy * remaining), display: true)
    self.alphaValue = style.animFade >= 0.5 ? max(0, min(1, self.progress)) : 1
    self.bannerViewController.setAppearance(self.progress)
  }

  /// Drives `progress` to `target` along the same spring SwiftUI uses, starting from the current
  /// value at rest, and calls `done` when it has settled.
  private func runSpring(to target: CGFloat, done: @escaping () -> Void) {
    self.springTimer?.invalidate()
    let style = BlipChromeStyle.current
    let omega = 2 * Double.pi / max(0.05, style.animResponse)
    let zeta = min(1, max(0.05, style.animDamping))
    let start = self.progress
    let begin = CACurrentMediaTime()
    // Fraction of the distance still to go after t seconds, from rest.
    func remaining(_ t: Double) -> Double {
      if zeta >= 1 { return (1 + omega * t) * exp(-omega * t) }
      let wd = omega * (1 - zeta * zeta).squareRoot()
      return exp(-zeta * omega * t) * (cos(wd * t) + zeta * omega / wd * sin(wd * t))
    }
    let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] timer in
      guard let self else { timer.invalidate(); return }
      let t = CACurrentMediaTime() - begin
      let left = remaining(t)
      let settled = t > 0.1 && abs(left) < 0.002 || t > 3
      self.progress = settled ? target : target - (target - start) * CGFloat(left)
      self.applyProgress()
      if settled {
        timer.invalidate()
        self.springTimer = nil
        done()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.springTimer = timer
  }

  // MARK: Fade timing

  private func hoverStateDidChange(_ hovering: Bool) {
    self.isHovered = hovering
    if hovering {
      self.fadeTimer?.invalidate()
      self.fadeTimer = nil
    } else if self.isVisible {
      self.scheduleFade()
    }
  }

  private func scheduleFade() {
    self.fadeTimer?.invalidate()
    self.fadeTimer = nil
    guard self.content.duration > 0 else { return }
    self.fadeTimer = Timer.scheduledTimer(withTimeInterval: self.content.duration, repeats: false) { [weak self] _ in
      guard let self, !self.isHovered else { return }
      self.dismiss(reason: .timeout)
    }
  }

  // MARK: Geometry

  private func targetFrame() -> NSRect {
    let size = NSSize(width: self.content.width, height: Constants.height)
    let screen = NSScreen.screens.first(where: { $0.blipDisplayID == self.displayID }) ?? NSScreen.main
    let visibleFrame = screen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? NSRect(origin: .zero, size: size)
    let origin = NSPoint(
      x: visibleFrame.maxX - size.width - Constants.trailingInset + CGFloat(BlipChromeStyle.current.positionX),
      y: visibleFrame.maxY - size.height - Constants.topInset - self.content.verticalOffset - CGFloat(BlipChromeStyle.current.positionY)
    )
    // The window reaches `bleed` points past the banner's top-left, so the close button can sit
    // outside the corner.
    let bleed = BannerViewController.bleed
    return NSRect(x: origin.x - bleed, y: origin.y, width: size.width + bleed, height: size.height + bleed)
  }
}

extension NSScreen {
  var blipDisplayID: CGDirectDisplayID? {
    (self.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
  }
}

import AppKit

/// Shows macOS-style on-screen banners (the glass volume / brightness banner that appears
/// at the top right of the display). Safe to call from any thread.
///
/// ```swift
/// Blip.shared.show(.volume(level: 0.4))
/// Blip.shared.show(.brightness(level: 0.8), on: .pointer, handlers: .init(onLevelChange: { print($0) }))
/// ```
///
/// The host process needs a running `NSApplication` event loop (any normal app has one; a
/// command line tool can call `Blip.shared.runUntilDismissed { ... }`).
public final class Blip {
  public static let shared = Blip()

  private var panels: [CGDirectDisplayID: BannerPanel] = [:]
  private var exitWhenIdle = false

  private var appearanceObservation: BlipAppearanceObservation?

  public init() {
    self.appearanceObservation = BlipAppearance.observe { [weak self] _ in
      self?.panels.values.forEach { $0.reapplyAppearance() }
    }
  }

  /// Shows a banner and returns a handle to update or dismiss it. If a banner is already
  /// visible on the display it is updated in place, so rapid calls animate smoothly.
  @discardableResult
  public func show(_ content: BlipContent, on target: BlipDisplayTarget = .main, handlers: BlipHandlers = BlipHandlers()) -> BlipHandle {
    let handle = BlipHandle(banner: self)
    self.onMain {
      let displayIDs = self.displayIDs(for: target)
      handle.displayIDs = displayIDs
      for displayID in displayIDs {
        self.panel(for: displayID).present(content, handlers: handlers)
      }
    }
    return handle
  }

  /// Dismisses banners on a display (all displays by default).
  public func dismiss(on target: BlipDisplayTarget = .all, animated: Bool = true) {
    self.onMain {
      for displayID in self.displayIDs(for: target) {
        self.panels[displayID]?.dismiss(reason: .programmatic, animated: animated)
      }
    }
  }

  /// For command line tools: runs `setup` (where you show banners), then runs the event loop.
  /// With `exitsWhenIdle` (the default) the process exits once every banner has gone; pass `false`
  /// to keep running until the process is interrupted. Does not return.
  public func runUntilDismissed(exitsWhenIdle: Bool = true, setup: () -> Void) -> Never {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    self.exitWhenIdle = exitsWhenIdle
    setup()
    application.run()
    exit(0)
  }

  // MARK: Internals

  func updateLevel(_ level: Double, on displayIDs: [CGDirectDisplayID]) {
    self.onMain {
      for displayID in displayIDs { self.panels[displayID]?.update(level: level) }
    }
  }

  func dismiss(displayIDs: [CGDirectDisplayID]) {
    self.onMain {
      for displayID in displayIDs { self.panels[displayID]?.dismiss(reason: .programmatic) }
    }
  }

  private func panel(for displayID: CGDirectDisplayID) -> BannerPanel {
    if let panel = self.panels[displayID] { return panel }
    let panel = BannerPanel(displayID: displayID)
    panel.didDismiss = { [weak self] in self?.panelDidDismiss() }
    self.panels[displayID] = panel
    return panel
  }

  private func panelDidDismiss() {
    guard self.exitWhenIdle, self.panels.values.allSatisfy({ !$0.isVisible }) else { return }
    exit(0)
  }

  private func displayIDs(for target: BlipDisplayTarget) -> [CGDirectDisplayID] {
    switch target {
    case .main:
      return [CGMainDisplayID()]
    case let .display(id):
      return [id]
    case .all:
      let ids = NSScreen.screens.compactMap(\.blipDisplayID)
      return ids.isEmpty ? [CGMainDisplayID()] : ids
    case .pointer:
      let location = NSEvent.mouseLocation
      let screen = NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
      return [screen?.blipDisplayID ?? CGMainDisplayID()]
    }
  }

  private func onMain(_ work: @escaping () -> Void) {
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.async(execute: work)
    }
  }
}

/// A reference to a shown banner.
public final class BlipHandle {
  private weak var banner: Blip?
  fileprivate(set) var displayIDs: [CGDirectDisplayID] = []

  init(banner: Blip) {
    self.banner = banner
  }

  /// Moves the slider (for example when the value changed elsewhere).
  public func update(level: Double) {
    self.banner?.updateLevel(level, on: self.displayIDs)
  }

  public func dismiss() {
    self.banner?.dismiss(displayIDs: self.displayIDs)
  }
}

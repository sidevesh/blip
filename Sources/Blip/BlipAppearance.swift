import AppKit

/// The system settings that change how Liquid Glass looks, which Blip follows.
///
/// - **Tint amount**: the Liquid Glass slider in System Settings → Appearance (clear to tinted),
///   stored as `NSGlassTintAmount` in the global preferences.
/// - **Reduce Transparency**: Accessibility → Display. When on, glass is replaced by a solid fill.
struct BlipAppearance: Equatable {
  /// 0 is fully clear, 1 is fully tinted. Systems that have never changed the setting report
  /// `defaultGlassTintAmount`.
  var glassTintAmount: Double
  /// Accessibility → Display → Reduce Transparency.
  var reducesTransparency: Bool
  /// Whether the system is currently using the dark appearance.
  var isDark: Bool

  /// What the slider sits at when the user has never moved it. This is an assumption: macOS does not
  /// store the value until it is changed.
  static let defaultGlassTintAmount = 0.5

  /// Reads the settings as they are right now.
  static var current: BlipAppearance {
    BlipAppearance(
      glassTintAmount: readGlassTintAmount(),
      reducesTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
      isDark: UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    )
  }

  /// Calls `handler` on the main thread whenever one of the settings changes, including when the
  /// user moves the slider in System Settings while your app is running. Keep the returned token for
  /// as long as you want updates, and pass it to `stopObserving` when done.
  @discardableResult
  static func observe(_ handler: @escaping (BlipAppearance) -> Void) -> BlipAppearanceObservation {
    let observation = BlipAppearanceObservation(handler: handler)
    observation.start()
    return observation
  }

  static func stopObserving(_ observation: BlipAppearanceObservation) {
    observation.stop()
  }

  private static func readGlassTintAmount() -> Double {
    // The value is written as a string ("0.5044006"), so accept either form.
    let value = UserDefaults.standard.object(forKey: "NSGlassTintAmount")
    let amount = (value as? NSNumber)?.doubleValue ?? (value as? String).flatMap(Double.init)
    return max(0, min(1, amount ?? defaultGlassTintAmount))
  }
}

/// Returned by `BlipAppearance.observe`.
///
/// Uses key-value observing on the preference keys, because `UserDefaults.didChangeNotification`
/// only reports changes made by the observing process itself.
final class BlipAppearanceObservation: NSObject {
  private static let keys = ["NSGlassTintAmount", "AppleInterfaceStyle"]

  private let handler: (BlipAppearance) -> Void
  private var last = BlipAppearance.current
  private var accessibilityToken: NSObjectProtocol?
  private var isObserving = false

  fileprivate init(handler: @escaping (BlipAppearance) -> Void) {
    self.handler = handler
  }

  fileprivate func start() {
    guard !self.isObserving else { return }
    self.isObserving = true
    for key in Self.keys {
      UserDefaults.standard.addObserver(self, forKeyPath: key, options: [.new], context: nil)
    }
    self.accessibilityToken = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.notifyIfChanged() }
  }

  fileprivate func stop() {
    guard self.isObserving else { return }
    self.isObserving = false
    for key in Self.keys { UserDefaults.standard.removeObserver(self, forKeyPath: key) }
    if let token = self.accessibilityToken { NSWorkspace.shared.notificationCenter.removeObserver(token) }
    self.accessibilityToken = nil
  }

  deinit { self.stop() }

  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
    DispatchQueue.main.async { [weak self] in self?.notifyIfChanged() }
  }

  private func notifyIfChanged() {
    let now = BlipAppearance.current
    guard now != self.last else { return }
    self.last = now
    self.handler(now)
  }
}

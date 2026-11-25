import AppKit

/// An icon shown in a banner: an SF Symbol, one of the built-in system icons,
/// or any image of your own.
public enum BlipIcon {
  /// Any SF Symbol by name, e.g. `"speaker.wave.2.fill"`.
  case symbol(String)
  /// One of the built-in icons macOS itself uses for its on-screen displays.
  case system(BlipSystemIcon)
  /// A custom image. Template images are tinted white like the symbols.
  case image(NSImage)
  /// A custom image loaded from a file (PNG, PDF, SVG, ICNS, ...).
  case file(URL)

  /// Renders the icon. Symbols use `pointSize`/`weight`; custom images are used as given.
  public func makeImage(pointSize: CGFloat = 13.8, weight: NSFont.Weight = .regular) -> NSImage? {
    switch self {
    case let .symbol(name):
      return Self.symbolImage(named: name, pointSize: pointSize, weight: weight)
    case let .system(icon):
      return Self.symbolImage(named: icon.symbolName, pointSize: pointSize, weight: weight)
    case let .image(image):
      return image
    case let .file(url):
      return NSImage(contentsOf: url)
    }
  }

  static func symbolImage(named name: String, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage? {
    // SF Symbols exist from macOS 11; earlier systems get no icon rather than a crash.
    guard #available(macOS 11.0, *) else { return nil }
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? Self.privateSymbol(named: name)
    return image?.withSymbolConfiguration(configuration)
  }

  /// Symbols the system keeps out of the public SF Symbols set, such as the Bluetooth logo.
  private static func privateSymbol(named name: String) -> NSImage? {
    let selector = NSSelectorFromString("imageWithPrivateSystemSymbolName:accessibilityDescription:")
    guard NSImage.responds(to: selector) else { return nil }
    return (NSImage.self as AnyObject).perform(selector, with: name, with: nil)?.takeUnretainedValue() as? NSImage
  }
}

/// Built-in icons covering what the macOS on-screen displays use. Each maps to an
/// SF Symbol; `rawValue` is a stable kebab-case name (used by the CLI).
public enum BlipSystemIcon: String, CaseIterable {
  // Display
  case brightnessLow = "brightness-low"
  case brightnessHigh = "brightness-high"
  case contrast
  case display
  case displays
  // Keyboard backlight
  case keyboardBrightnessLow = "keyboard-brightness-low"
  case keyboardBrightnessHigh = "keyboard-brightness-high"
  case keyboard
  case capsLock = "caps-lock"
  // Sound
  case volumeLow = "volume-low"
  case volumeMedium = "volume-medium"
  case volumeHigh = "volume-high"
  case volumeMuted = "volume-muted"
  case speaker
  case microphone
  case microphoneMuted = "microphone-muted"
  case headphones
  case airpods
  case airpodsPro = "airpods-pro"
  case airpodsMax = "airpods-max"
  // Power
  case batteryEmpty = "battery-empty"
  case batteryLow = "battery-low"
  case batteryHalf = "battery-half"
  case batteryHigh = "battery-high"
  case batteryFull = "battery-full"
  case batteryCharging = "battery-charging"
  case powerPlug = "power-plug"
  case power
  case sleep
  case restart
  // Modes and connectivity
  case focus
  case notifications
  case notificationsOff = "notifications-off"
  case airplane
  case bluetooth
  case bluetoothOff = "bluetooth-off"
  case wifi
  case wifiOff = "wifi-off"
  case wireless
  case lock
  case unlock
  case eject
  // Media
  case play
  case pause
  case playPause = "play-pause"
  case next
  case previous
  // Capture and input
  case camera
  case cameraOff = "camera-off"
  case screenshot
  case screenRecording = "screen-recording"
  case clipboard
  case mouse
  case magicMouse = "magic-mouse"
  // Status
  case checkmark
  case error
  case warning
  case info

  /// The SF Symbol this icon is drawn with.
  public var symbolName: String {
    switch self {
    case .brightnessLow: return "sun.min.fill"
    case .brightnessHigh: return "sun.max.fill"
    case .contrast: return "circle.lefthalf.filled"
    case .display: return "display"
    case .displays: return "display.2"
    case .keyboardBrightnessLow: return "light.min"
    case .keyboardBrightnessHigh: return "light.max"
    case .keyboard: return "keyboard.fill"
    case .capsLock: return "capslock.fill"
    case .volumeLow: return "speaker.wave.1.fill"
    case .volumeMedium: return "speaker.wave.2.fill"
    case .volumeHigh: return "speaker.wave.3.fill"
    case .volumeMuted: return "speaker.slash.fill"
    case .speaker: return "speaker.fill"
    case .microphone: return "mic.fill"
    case .microphoneMuted: return "mic.slash.fill"
    case .headphones: return "headphones"
    case .airpods: return "airpods"
    case .airpodsPro: return "airpodspro"
    case .airpodsMax: return "airpodsmax"
    case .batteryEmpty: return "battery.0percent"
    case .batteryLow: return "battery.25percent"
    case .batteryHalf: return "battery.50percent"
    case .batteryHigh: return "battery.75percent"
    case .batteryFull: return "battery.100percent"
    case .batteryCharging: return "battery.100percent.bolt"
    case .powerPlug: return "powerplug.fill"
    case .power: return "power"
    case .sleep: return "powersleep"
    case .restart: return "restart"
    case .focus: return "moon.fill"
    case .notifications: return "bell.fill"
    case .notificationsOff: return "bell.slash.fill"
    case .airplane: return "airplane"
    case .bluetooth: return "bluetooth"
    case .bluetoothOff: return "bluetooth.slash"
    case .wifi: return "wifi"
    case .wifiOff: return "wifi.slash"
    case .wireless: return "dot.radiowaves.left.and.right"
    case .lock: return "lock.fill"
    case .unlock: return "lock.open.fill"
    case .eject: return "eject.fill"
    case .play: return "play.fill"
    case .pause: return "pause.fill"
    case .playPause: return "playpause.fill"
    case .next: return "forward.fill"
    case .previous: return "backward.fill"
    case .camera: return "camera.fill"
    case .cameraOff: return "video.slash.fill"
    case .screenshot: return "camera.viewfinder"
    case .screenRecording: return "record.circle"
    case .clipboard: return "doc.on.clipboard.fill"
    case .mouse: return "computermouse.fill"
    case .magicMouse: return "magicmouse.fill"
    case .checkmark: return "checkmark.circle.fill"
    case .error: return "xmark.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    case .info: return "info.circle.fill"
    }
  }

  /// A battery icon matching a charge percentage.
  public static func battery(percent: Int, charging: Bool = false) -> BlipSystemIcon {
    if charging { return .batteryCharging }
    switch percent {
    case ..<10: return .batteryEmpty
    case ..<35: return .batteryLow
    case ..<60: return .batteryHalf
    case ..<85: return .batteryHigh
    default: return .batteryFull
    }
  }
}

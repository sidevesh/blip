import AppKit

/// What a banner shows. Build one with a preset (`.volume(level:)`, `.brightness(level:)`, ...)
/// or with `.slider(...)` / `.message(...)`. The look itself is fixed: it is the system's, and so is
/// the shape: a title over either a slider or a second line, never a title alone.
public struct BlipContent {
  public enum Layout {
    /// A title, a slider with an icon at each end, and tick markers underneath.
    case slider
    /// A title and a second line, with an icon, e.g. a low battery notice. Like the system's
    /// banners it always has both lines.
    case message
  }

  public internal(set) var layout: Layout
  public var title: String
  /// Second line (message layout only).
  public internal(set) var message: String?
  /// Left icon in the slider layout; the main icon in the message layout.
  public var leadingIcon: BlipIcon?
  /// Right icon in the slider layout. Unused by the message layout.
  public var trailingIcon: BlipIcon?
  /// Slider position, 0...1.
  public var level: Double
  /// Lets the user drag the slider, click the end icons and tap the banner.
  /// Non-interactive banners let mouse clicks pass through.
  public var isInteractive: Bool
  /// Seconds before the banner fades out. `0` keeps it until `dismiss()` is called.
  public var duration: TimeInterval

  var leadingIconSize: CGFloat = 19
  var trailingIconSize: CGFloat = 20
  var showsMarkers = true
  var width: CGFloat = 293
  var messageIconPlacement = BlipMessageIconPlacement.trailing
  @_spi(Tuning) public var verticalOffset: CGFloat = 0

  init(
    layout: Layout = .slider,
    title: String = "",
    message: String? = nil,
    leadingIcon: BlipIcon? = nil,
    trailingIcon: BlipIcon? = nil,
    level: Double = 0,
    isInteractive: Bool = false,
    duration: TimeInterval = 1.15
  ) {
    self.layout = layout
    self.title = title
    self.message = message
    self.leadingIcon = leadingIcon
    self.trailingIcon = trailingIcon
    self.level = level
    self.isInteractive = isInteractive
    self.duration = duration
  }
}

/// A blur drawn under the glass.
enum BlipBlurMaterial {
  case hud
  case popover
  case fullScreenUI
}

/// A glass recipe built by hand, for trying looks that the named styles don't cover. `variant` is
/// one of `NSGlassEffectView`'s private variants (0 is the plain one); the system ignores values it
/// does not support.
struct BlipGlassRecipe {
  /// The `NSGlassEffectView` style: `.regular` when true, `.clear` when false.
  var regular: Bool
  var variant: Int?
  var blur: BlipBlurMaterial?
  /// Strength of the dark scrim at the default tint setting, 0...1.
  var scrim: Double
  /// How strongly the glass is drawn over the blur, 0...1. Below 1 the glass fades, so less of its
  /// lensing and rim shows.
  var glassOpacity: Double
  /// Radius in points of a plain gaussian blur under the glass, with no darkening. `nil` uses the
  /// `blur` material instead.
  var blurRadius: Double?
  /// The system banner's fill, fitted to measurements of the real thing at the default tint: the
  /// backdrop's saturation is nearly doubled and its tone curve is flattened (black lifts to about
  /// 14 percent, white drops to about 81 percent, before the glass layer adds its own lift). 1 is that fill at the system's default tint, 0 is
  /// none; the value is scaled by the system's Liquid Glass tint setting. `nil` uses `scrim` instead.
  var fill: Double?
  /// How much of the glass's bright rim highlight shows, 0...1. 1 leaves the glass as it is; below
  /// that a thin dark edge fades the highlight out.
  var gleam: Double

  init(
    regular: Bool = true,
    variant: Int? = nil,
    blur: BlipBlurMaterial? = nil,
    scrim: Double = 0,
    glassOpacity: Double = 1,
    blurRadius: Double? = nil,
    fill: Double? = nil,
    gleam: Double = 1
  ) {
    self.regular = regular
    self.variant = variant
    self.blur = blur
    self.scrim = scrim
    self.glassOpacity = glassOpacity
    self.blurRadius = blurRadius
    self.fill = fill
    self.gleam = gleam
  }
}

/// Where the icon sits in the message layout. The title and subtitle always keep the same
/// position as in the slider layout.
enum BlipMessageIconPlacement {
  /// At the right edge, vertically centred.
  case trailing
  /// No icon.
  case none
}

// MARK: - Presets

/// Text macOS itself uses on its banners, read from the system's own localization so it follows
/// the user's language. Falls back to the English text.
enum BlipNativeText {
  private static let bundle = Bundle(path: "/System/Library/PrivateFrameworks/SystemBannerUI.framework")

  static func string(_ key: String) -> String {
    bundle?.localizedString(forKey: key, value: key, table: "SystemBannerUI") ?? key
  }
}

public extension BlipContent {
  /// A fully custom slider banner.
  static func slider(title: String, level: Double, leading: BlipIcon?, trailing: BlipIcon?) -> BlipContent {
    BlipContent(layout: .slider, title: title, leadingIcon: leading, trailingIcon: trailing, level: level)
  }

  /// A title with a second line where the slider would be, and an optional icon. The system's
  /// banners always have that second line, so `message` is required.
  static func message(title: String, message: String, icon: BlipIcon?) -> BlipContent {
    var content = BlipContent(layout: .message, title: title, message: message, leadingIcon: icon)
    content.leadingIconSize = 26
    return content
  }

  static func brightness(level: Double, title: String? = nil) -> BlipContent {
    .slider(title: title ?? BlipNativeText.string("Display"), level: level, leading: .system(.brightnessLow), trailing: .system(.brightnessHigh))
  }

  static func keyboardBrightness(level: Double, title: String? = nil) -> BlipContent {
    var content = BlipContent.slider(
      title: title ?? BlipNativeText.string("Keyboard Brightness"),
      level: level,
      leading: .system(.keyboardBrightnessLow),
      trailing: .system(.keyboardBrightnessHigh)
    )
    content.trailingIconSize = 22
    return content
  }

  static func contrast(level: Double, title: String = "Contrast") -> BlipContent {
    .slider(title: title, level: level, leading: .system(.contrast), trailing: .system(.contrast))
  }

  /// A volume slider titled "Sound" like the system's. A muted level shows the slashed speaker.
  static func volume(level: Double, muted: Bool = false, title: String? = nil) -> BlipContent {
    var content = BlipContent.slider(
      title: title ?? BlipNativeText.string("Sound"),
      level: muted ? 0 : level,
      leading: .system(muted ? .volumeMuted : .speaker),
      trailing: .system(.volumeHigh)
    )
    // Sizes measured against the system banner: a plain speaker on the left, three waves on the right.
    content.leadingIconSize = 18
    content.trailingIconSize = 25
    return content
  }

  /// "Low Battery" with "Plug in soon to recharge", using the system's wording.
  static func lowBattery(percent: Int? = nil) -> BlipContent {
    .message(
      title: BlipNativeText.string("Low Battery"),
      message: BlipNativeText.string("Plug in soon to recharge"),
      icon: .system(BlipSystemIcon.battery(percent: percent ?? 10))
    )
  }

  /// "Charging", with the time to full such as `"1:20"` when known, or "Connected to power".
  static func charging(timeUntilFull: String? = nil) -> BlipContent {
    let message = timeUntilFull.map { String(format: BlipNativeText.string("%@ until fully charged"), $0) } ?? "Connected to power"
    return .message(title: BlipNativeText.string("Charging"), message: message, icon: .system(.batteryCharging))
  }

  /// "Low Power" with "Low Power Mode Enabled".
  static func lowPowerMode() -> BlipContent {
    .message(
      title: BlipNativeText.string("Low Power"),
      message: BlipNativeText.string("Low Power Mode Enabled"),
      icon: .system(.batteryHalf)
    )
  }

  /// A connected accessory, with its battery level when known ("80% Battery"), else "Connected".
  static func accessory(name: String, batteryPercent: Int? = nil, icon: BlipIcon? = .system(.headphones)) -> BlipContent {
    let detail = batteryPercent.map { String(format: BlipNativeText.string("%@ Battery"), "\($0)%") } ?? BlipNativeText.string("HID_DEVICE_CONNECTED")
    return .message(title: name, message: detail, icon: icon)
  }

  /// A Focus mode with "On" / "Off".
  static func focus(name: String = "Focus", on: Bool) -> BlipContent {
    .message(title: name, message: BlipNativeText.string(on ? "FOCUS_MODE_ON" : "FOCUS_MODE_OFF"), icon: .system(.focus))
  }

  /// "Listening Mode" with the mode name, e.g. "Noise Cancellation".
  static func listeningMode(_ mode: String, icon: BlipIcon? = .system(.airpodsPro)) -> BlipContent {
    .message(title: BlipNativeText.string("Listening Mode"), message: mode, icon: icon)
  }

  /// A microphone mute notice.
  static func microphone(muted: Bool, title: String = "Microphone") -> BlipContent {
    .message(title: title, message: muted ? "Muted" : "On", icon: .system(muted ? .microphoneMuted : .microphone))
  }
}

// MARK: - Interaction

/// Which end icon of the slider was clicked.
public enum BlipStep {
  case decrease
  case increase
}

/// Why a banner went away.
public enum BlipDismissReason {
  case timeout
  case programmatic
  /// The close button that appears while the pointer is over an interactive banner was clicked.
  case closeButton
}

/// Callbacks for an interactive banner. All are called on the main thread.
public struct BlipHandlers {
  /// The slider was dragged (continuously while dragging).
  public var onLevelChange: ((Double) -> Void)?
  /// An end icon was clicked.
  public var onStep: ((BlipStep) -> Void)?
  /// The banner (outside the slider and icons) was clicked.
  public var onTap: (() -> Void)?
  /// The banner faded out or was dismissed. Not called when a newer banner replaces this one.
  public var onDismiss: ((BlipDismissReason) -> Void)?

  public init(
    onLevelChange: ((Double) -> Void)? = nil,
    onStep: ((BlipStep) -> Void)? = nil,
    onTap: (() -> Void)? = nil,
    onDismiss: ((BlipDismissReason) -> Void)? = nil
  ) {
    self.onLevelChange = onLevelChange
    self.onStep = onStep
    self.onTap = onTap
    self.onDismiss = onDismiss
  }
}

/// Which display a banner appears on.
public enum BlipDisplayTarget {
  /// The primary display (the one with the menu bar).
  case main
  /// The display the mouse pointer is on.
  case pointer
  /// A specific display.
  case display(CGDirectDisplayID)
  /// Every connected display.
  case all
}

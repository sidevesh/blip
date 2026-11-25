import Foundation

/// A media key action for ``BlipContent/media(_:)``.
public enum BlipMediaAction {
  case play, pause, playPause, next, previous
}

/// The kind of notice for ``BlipContent/status(_:title:message:)``.
public enum BlipStatusKind {
  case success, error, warning, info
}

public extension BlipContent {
  // MARK: Sound

  /// A volume slider titled with an output device name, like the system shows when the output is
  /// a named device, e.g. `.soundOutput(device: "WH-1000XM5", level: 0.4)`.
  static func soundOutput(device: String, level: Double) -> BlipContent {
    .volume(level: level, title: device)
  }

  /// A notice for muting or unmuting every microphone at once.
  static func allMicrophones(muted: Bool) -> BlipContent {
    .message(
      title: "All Microphones",
      message: muted ? "Muted" : "Unmuted",
      icon: .system(muted ? .microphoneMuted : .microphone)
    )
  }

  // MARK: On / off notices

  /// A generic title with "On" or "Off" under it.
  static func toggle(title: String, on: Bool, icon: BlipIcon?, onText: String = "On", offText: String = "Off") -> BlipContent {
    .message(title: title, message: on ? onText : offText, icon: icon)
  }

  static func camera(on: Bool) -> BlipContent {
    .toggle(title: "Camera", on: on, icon: .system(on ? .camera : .cameraOff))
  }

  static func capsLock(on: Bool) -> BlipContent {
    .toggle(title: "Caps Lock", on: on, icon: .system(.capsLock))
  }

  static func wifi(on: Bool) -> BlipContent {
    .toggle(title: "Wi-Fi", on: on, icon: .system(on ? .wifi : .wifiOff))
  }

  static func bluetooth(on: Bool) -> BlipContent {
    .toggle(title: "Bluetooth", on: on, icon: .system(on ? .bluetooth : .bluetoothOff))
  }

  static func airplaneMode(on: Bool) -> BlipContent {
    .toggle(title: "Airplane Mode", on: on, icon: .system(.airplane))
  }

  static func notifications(on: Bool) -> BlipContent {
    .toggle(title: "Notifications", on: on, icon: .system(on ? .notifications : .notificationsOff))
  }

  static func screenLock(locked: Bool) -> BlipContent {
    .toggle(title: "Screen", on: locked, icon: .system(locked ? .lock : .unlock), onText: "Locked", offText: "Unlocked")
  }

  // MARK: Media

  static func media(_ action: BlipMediaAction) -> BlipContent {
    switch action {
    case .play: return .message(title: "Now Playing", message: "Playing", icon: .system(.play))
    case .pause: return .message(title: "Now Playing", message: "Paused", icon: .system(.pause))
    case .playPause: return .message(title: "Now Playing", message: "Play / Pause", icon: .system(.playPause))
    case .next: return .message(title: "Now Playing", message: "Next Track", icon: .system(.next))
    case .previous: return .message(title: "Now Playing", message: "Previous Track", icon: .system(.previous))
    }
  }

  // MARK: Battery

  /// A battery level, with "Charging" when plugged in. Use ``accessory(name:batteryPercent:icon:)``
  /// to attach a device name instead.
  static func battery(percent: Int, charging: Bool = false) -> BlipContent {
    .message(
      title: charging ? "Charging" : "Battery",
      message: "\(percent)%",
      icon: .system(BlipSystemIcon.battery(percent: percent, charging: charging))
    )
  }

  // MARK: Mouse and keyboard settings (for tools like OpenLogi)

  /// A pointer speed slider.
  static func pointerSpeed(level: Double) -> BlipContent {
    .slider(title: "Pointer Speed", level: level, leading: .system(.mouse), trailing: .system(.mouse))
  }

  /// A DPI value, e.g. `.dpi(1600)`, with the level under it when known.
  static func dpi(_ value: Int, device: String? = nil) -> BlipContent {
    .message(title: device ?? "Pointer Speed", message: "\(value) DPI", icon: .system(.mouse))
  }

  /// A scroll speed slider.
  static func scrollSpeed(level: Double) -> BlipContent {
    .slider(title: "Scroll Speed", level: level, leading: .system(.mouse), trailing: .system(.mouse))
  }

  /// A scroll wheel mode, as on mice with a switchable wheel.
  static func smartShift(freeSpin: Bool) -> BlipContent {
    .message(title: "Scroll Wheel", message: freeSpin ? "Free-spin" : "Ratchet", icon: .system(.mouse))
  }

  /// A host channel for devices that pair with several computers.
  static func easySwitch(channel: Int, device: String? = nil) -> BlipContent {
    .message(title: device ?? "Easy-Switch", message: "Channel \(channel)", icon: .system(.wireless))
  }

  /// Natural or traditional scroll direction.
  static func scrollDirection(natural: Bool) -> BlipContent {
    .message(title: "Scroll Direction", message: natural ? "Natural" : "Traditional", icon: .symbol("arrow.up.arrow.down"))
  }

  // MARK: General

  /// A success, error, warning or information notice.
  static func status(_ kind: BlipStatusKind, title: String, message: String) -> BlipContent {
    let icon: BlipSystemIcon
    switch kind {
    case .success: icon = .checkmark
    case .error: icon = .error
    case .warning: icon = .warning
    case .info: icon = .info
    }
    return .message(title: title, message: message, icon: .system(icon))
  }

  static func screenshot() -> BlipContent {
    .message(title: "Screenshot", message: "Saved", icon: .system(.screenshot))
  }

  static func clipboardCopied() -> BlipContent {
    .message(title: "Copied", message: "Copied to the clipboard", icon: .system(.clipboard))
  }
}

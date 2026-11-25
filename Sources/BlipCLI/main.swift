import AppKit
import Darwin
import Blip

// blip — show a macOS-style on-screen banner from the command line.

let usage = """
blip — show a macOS-style on-screen banner

USAGE
  blip PRESET [options]
  blip list-presets | list-icons | demo | tuner | help

PRESETS
  brightness            display brightness slider        (--level)
  keyboard-brightness   keyboard backlight slider        (--level)
  volume                volume slider                    (--level, --muted)
  mute                  volume slider showing muted
  contrast              contrast slider                  (--level)
  microphone            microphone notice                (--muted)
  microphone-muted      microphone muted notice
  low-battery           "Low Battery" notice             (--percent)
  charging              "Charging" notice                (--time-until-full)
  low-power             "Low Power Mode Enabled" notice
  accessory             connected accessory              (--title NAME, --percent, --icon)
  listening-mode        listening mode notice            (--message MODE)
  focus                 focus notice                     (--title NAME, --off)
  slider                custom slider                    (--title, --icon, --trailing-icon, --level)
  message               custom icon + text               (--title, --message, --icon)
  sound-output          volume slider titled by a device (--title NAME, --level)
  all-microphones       all microphones notice           (--muted)
  camera / caps-lock / wifi / bluetooth / airplane-mode / notifications   on/off notices (--off)
  screen-lock           screen locked notice             (--off for unlocked)
  play pause play-pause next previous   media key notices
  battery               battery level                    (--percent, --charging)
  pointer-speed         pointer speed slider             (--level)
  dpi                   DPI notice                       (--value N, --title DEVICE)
  scroll-speed          scroll speed slider              (--level)
  smart-shift           scroll wheel mode                (--off for ratchet)
  easy-switch           host channel                     (--value N, --title DEVICE)
  scroll-direction      natural/traditional scrolling    (--off for traditional)
  success error warning info   status notices            (--title, --message)
  screenshot / clipboard   capture and copy notices

OPTIONS
  --level N             slider position, 0–1 (or 0–100)
  --title TEXT          title text
  --message TEXT        second line (message layout)
  --icon ICON           leading icon (see ICONS)
  --trailing-icon ICON  trailing icon (slider layout)
  --muted / --off       mute / off state of the preset
  --percent N           battery percentage
  --charging            charging state (battery)
  --value N             number for dpi, easy-switch
  --time-until-full T   time to full charge, e.g. 1:20
  --interactive         allow dragging the slider and clicking icons
  --duration SECONDS    time before fading out; 0 keeps it until clicked (default 1.15)
  --display TARGET      main (default), pointer, all, or a display ID
  --events              print what the user does as JSON lines on stdout
  --background          return immediately and keep the banner alive in the background

ICONS
  system-name           a built-in icon, see `blip list-icons`
  sf:NAME               any SF Symbol, e.g. sf:speaker.wave.2.fill
  file:PATH or a path   an image file (PNG, PDF, SVG, ICNS)

EVENTS (with --events)
  {"event":"level","value":0.42}   slider dragged
  {"event":"step","direction":"increase"}   an end icon clicked
  {"event":"tap"}                  banner clicked
  {"event":"dismiss","reason":"timeout"}

EXAMPLES
  blip volume --level 0.4
  blip keyboard-brightness --level 0.75 --display pointer
  blip microphone --muted --background
  blip message --icon wifi-off --title "Wi-Fi" --message "Disconnected"
  blip slider --title Fan --icon sf:fan --trailing-icon sf:fan.fill --interactive --events

"""

// MARK: - Argument parsing

struct Options {
  var preset = ""
  var level: Double?
  var title: String?
  var message: String?
  var icon: String?
  var trailingIcon: String?
  var muted = false
  var off = false
  var percent: Int?
  var charging = false
  var value: Int?
  var timeUntilFull: String?
  var interactive = false
  var duration: Double?
  var display = "main"
  var events = false
  var background = false
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("blip: \(message)\n".utf8))
  exit(1)
}

func parseOptions(_ arguments: [String]) -> Options {
  var options = Options()
  var index = 0

  func value(_ name: String, inline: String?) -> String {
    if let inline { return inline }
    index += 1
    guard index < arguments.count else { fail("\(name) needs a value") }
    return arguments[index]
  }

  func number(_ name: String, _ text: String) -> Double {
    guard let number = Double(text) else { fail("\(name) expects a number, got \"\(text)\"") }
    return number
  }

  while index < arguments.count {
    var argument = arguments[index]
    var inline: String?
    if argument.hasPrefix("--"), let equals = argument.firstIndex(of: "=") {
      inline = String(argument[argument.index(after: equals)...])
      argument = String(argument[..<equals])
    }

    switch argument {
    case "--level": options.level = number(argument, value(argument, inline: inline))
    case "--title": options.title = value(argument, inline: inline)
    case "--message": options.message = value(argument, inline: inline)
    case "--icon": options.icon = value(argument, inline: inline)
    case "--trailing-icon": options.trailingIcon = value(argument, inline: inline)
    case "--muted": options.muted = true
    case "--off": options.off = true
    case "--charging": options.charging = true
    case "--value": options.value = Int(number(argument, value(argument, inline: inline)))
    case "--percent": options.percent = Int(number(argument, value(argument, inline: inline)))
    case "--time-until-full": options.timeUntilFull = value(argument, inline: inline)
    case "--interactive": options.interactive = true
    case "--duration": options.duration = number(argument, value(argument, inline: inline))
    case "--display": options.display = value(argument, inline: inline)
    case "--events": options.events = true
    case "--background": options.background = true
    default:
      if argument.hasPrefix("-") { fail("unknown option \(argument) (try `blip help`)") }
      if options.preset.isEmpty { options.preset = argument } else { fail("unexpected argument \"\(argument)\"") }
    }
    index += 1
  }
  return options
}

// MARK: - Building content

func icon(from spec: String) -> BlipIcon {
  if spec.hasPrefix("sf:") { return .symbol(String(spec.dropFirst(3))) }
  if spec.hasPrefix("file:") { return .file(URL(fileURLWithPath: (String(spec.dropFirst(5)) as NSString).expandingTildeInPath)) }
  if let system = BlipSystemIcon(rawValue: spec) { return .system(system) }
  if spec.contains("/") || spec.contains(".") {
    let path = (spec as NSString).expandingTildeInPath
    if FileManager.default.fileExists(atPath: path) { return .file(URL(fileURLWithPath: path)) }
  }
  fail("unknown icon \"\(spec)\" (use a name from `list-icons`, sf:NAME, or a file path)")
}

func normalizedLevel(_ level: Double?) -> Double {
  guard let level else { return 0.5 }
  return max(0, min(1, level > 1 ? level / 100 : level))
}

func buildContent(_ options: Options) -> BlipContent {
  let level = normalizedLevel(options.level)
  var content: BlipContent

  switch options.preset {
  case "brightness": content = .brightness(level: level)
  case "keyboard-brightness": content = .keyboardBrightness(level: level)
  case "volume": content = .volume(level: level, muted: options.muted)
  case "mute": content = .volume(level: 0, muted: true)
  case "contrast": content = .contrast(level: level)
  case "microphone": content = .microphone(muted: options.muted)
  case "microphone-muted": content = .microphone(muted: true)
  case "low-battery": content = .lowBattery(percent: options.percent)
  case "charging": content = .charging(timeUntilFull: options.timeUntilFull)
  case "low-power": content = .lowPowerMode()
  case "accessory":
    content = .accessory(name: options.title ?? "Accessory", batteryPercent: options.percent)
  case "listening-mode": content = .listeningMode(options.message ?? "Noise Cancellation")
  case "focus": content = .focus(name: options.title ?? "Focus", on: !options.off)
  case "sound-output": content = .soundOutput(device: options.title ?? "Speakers", level: level)
  case "all-microphones": content = .allMicrophones(muted: options.muted)
  case "camera": content = .camera(on: !options.off)
  case "caps-lock": content = .capsLock(on: !options.off)
  case "wifi": content = .wifi(on: !options.off)
  case "bluetooth": content = .bluetooth(on: !options.off)
  case "airplane-mode": content = .airplaneMode(on: !options.off)
  case "notifications": content = .notifications(on: !options.off)
  case "screen-lock": content = .screenLock(locked: !options.off)
  case "play": content = .media(.play)
  case "pause": content = .media(.pause)
  case "play-pause": content = .media(.playPause)
  case "next": content = .media(.next)
  case "previous": content = .media(.previous)
  case "battery": content = .battery(percent: options.percent ?? 80, charging: options.charging)
  case "pointer-speed": content = .pointerSpeed(level: level)
  case "dpi": content = .dpi(options.value ?? 1600, device: options.title)
  case "scroll-speed": content = .scrollSpeed(level: level)
  case "smart-shift": content = .smartShift(freeSpin: !options.off)
  case "easy-switch": content = .easySwitch(channel: options.value ?? 1, device: options.title)
  case "scroll-direction": content = .scrollDirection(natural: !options.off)
  case "success": content = .status(.success, title: options.title ?? "Done", message: options.message ?? "Completed")
  case "error": content = .status(.error, title: options.title ?? "Error", message: options.message ?? "Something went wrong")
  case "warning": content = .status(.warning, title: options.title ?? "Warning", message: options.message ?? "Needs your attention")
  case "info": content = .status(.info, title: options.title ?? "Info", message: options.message ?? "For your information")
  case "screenshot": content = .screenshot()
  case "clipboard": content = .clipboardCopied()
  case "slider":
    content = .slider(title: "", level: level, leading: nil, trailing: nil)
  case "message":
    // The system's banners always have a second line.
    guard let message = options.message, !message.isEmpty else { fail("message needs --message (the second line)") }
    content = .message(title: "", message: message, icon: nil)
  default:
    fail("unknown preset \"\(options.preset)\" (try `blip list-presets`)")
  }

  if let title = options.title { content.title = title }
  if let spec = options.icon { content.leadingIcon = icon(from: spec) }
  if let spec = options.trailingIcon { content.trailingIcon = icon(from: spec) }
  if let duration = options.duration { content.duration = duration }
  content.isInteractive = options.interactive || options.events
  return content
}

func displayTarget(_ text: String) -> BlipDisplayTarget {
  switch text {
  case "main": return .main
  case "pointer": return .pointer
  case "all": return .all
  default:
    guard let id = UInt32(text) else { fail("--display expects main, pointer, all or a display ID") }
    return .display(id)
  }
}

// MARK: - Output

func emit(_ object: [String: Any]) {
  guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
        let line = String(data: data, encoding: .utf8) else { return }
  print(line)
  fflush(stdout)
}

func makeHandlers(printEvents: Bool) -> BlipHandlers {
  guard printEvents else { return BlipHandlers() }
  return BlipHandlers(
    onLevelChange: { emit(["event": "level", "value": ($0 * 1000).rounded() / 1000]) },
    onStep: { emit(["event": "step", "direction": $0 == .increase ? "increase" : "decrease"]) },
    onTap: { emit(["event": "tap"]) },
    onDismiss: { emit(["event": "dismiss", "reason": $0 == .timeout ? "timeout" : "programmatic"]) }
  )
}

// MARK: - Background mode

/// Re-launches this tool detached from the terminal so scripts get their prompt back at once.
func relaunchInBackground() -> Never {
  var environment = ProcessInfo.processInfo.environment
  environment["BLIP_FOREGROUND"] = "1"
  let environmentStrings = environment.map { "\($0.key)=\($0.value)" }

  let path = Bundle.main.executablePath ?? CommandLine.arguments[0]
  let arguments = [path] + CommandLine.arguments.dropFirst().filter { $0 != "--background" }

  var attributes: posix_spawnattr_t?
  posix_spawnattr_init(&attributes)
  posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID))
  var actions: posix_spawn_file_actions_t?
  posix_spawn_file_actions_init(&actions)
  posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
  posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0)
  posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0)

  var childArguments: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) } + [nil]
  var childEnvironment: [UnsafeMutablePointer<CChar>?] = environmentStrings.map { strdup($0) } + [nil]
  var pid: pid_t = 0
  let status = posix_spawn(&pid, path, &actions, &attributes, &childArguments, &childEnvironment)
  if status != 0 { fail("could not start background process (\(String(cString: strerror(status))))") }
  exit(0)
}

// MARK: - Demo

func runDemo() -> Never {
  let banner = Blip.shared
  var steps: [() -> Void] = []

  func show(_ content: BlipContent) {
    var content = content
    content.duration = 1.6
    content.isInteractive = true
    banner.show(content)
  }

  func sweep(_ make: @escaping (Double) -> BlipContent) {
    for step in 0 ... 10 {
      steps.append { show(make(Double(step) / 10)) }
    }
  }

  sweep { .volume(level: $0) }
  sweep { .brightness(level: $0) }
  sweep { .keyboardBrightness(level: $0) }
  steps.append { show(.volume(level: 0, muted: true)) }
  steps.append { show(.microphone(muted: true)) }
  steps.append { show(.microphone(muted: false)) }
  steps.append { show(.lowBattery()) }
  steps.append { show(.charging(timeUntilFull: "1:20")) }
  steps.append { show(.lowPowerMode()) }
  steps.append { show(.accessory(name: "AirPods Pro", batteryPercent: 80)) }
  steps.append { show(.listeningMode("Noise Cancellation")) }
  steps.append { show(.focus(name: "Do Not Disturb", on: true)) }
  steps.append { show(.message(title: "Wi-Fi", message: "Disconnected", icon: .system(.wifiOff))) }
  steps.append { show(.message(title: "Copied", message: "Clipboard updated", icon: .system(.clipboard))) }
  steps.append { show(.soundOutput(device: "DELL PROFESSIONAL SOUND BAR AE515", level: 0.3)) }
  steps.append { show(.allMicrophones(muted: true)) }
  steps.append { show(.allMicrophones(muted: false)) }
  steps.append { show(.camera(on: false)) }
  steps.append { show(.capsLock(on: true)) }
  steps.append { show(.wifi(on: false)) }
  steps.append { show(.bluetooth(on: true)) }
  steps.append { show(.airplaneMode(on: true)) }
  steps.append { show(.screenLock(locked: true)) }
  steps.append { show(.media(.playPause)) }
  steps.append { show(.media(.next)) }
  steps.append { show(.battery(percent: 80, charging: true)) }
  steps.append { show(.pointerSpeed(level: 0.6)) }
  steps.append { show(.dpi(1600, device: "MX Master 3S")) }
  steps.append { show(.scrollSpeed(level: 0.5)) }
  steps.append { show(.smartShift(freeSpin: true)) }
  steps.append { show(.easySwitch(channel: 2, device: "MX Keys")) }
  steps.append { show(.scrollDirection(natural: true)) }
  steps.append { show(.status(.success, title: "Saved", message: "Settings applied")) }
  steps.append { show(.status(.error, title: "Failed", message: "Device not found")) }
  steps.append { show(.status(.warning, title: "Low signal", message: "Move closer")) }
  steps.append { show(.screenshot()) }

  banner.runUntilDismissed {
    for (index, step) in steps.enumerated() {
      // Sweeps are quick; the notices linger a little longer.
      let delay = index < 33 ? Double(index) * 0.12 : 33 * 0.12 + Double(index - 33) * 1.3
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: step)
    }
  }
}

// MARK: - Main

var arguments = Array(CommandLine.arguments.dropFirst())

// Drop-in mode: when installed under the name of the older `mute-microphone-osd` tool
// ("mute-microphone-osd" = muted, "mute-microphone-osd un-muted" = unmuted), show the
// all-microphones banner instead, so existing callers keep working untouched.
if URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent == "mute-microphone-osd" {
  arguments = arguments.contains("un-muted")
    ? ["all-microphones", "--background"]
    : ["all-microphones", "--muted", "--background"]
}

guard let first = arguments.first else {
  print(usage)
  exit(1)
}

switch first {
case "help", "--help", "-h":
  print(usage)
  exit(0)
case "list-presets":
  print("brightness keyboard-brightness volume mute contrast microphone microphone-muted low-battery charging low-power accessory listening-mode focus slider message sound-output all-microphones camera caps-lock wifi bluetooth airplane-mode notifications screen-lock play pause play-pause next previous battery pointer-speed dpi scroll-speed smart-shift easy-switch scroll-direction success error warning info screenshot clipboard"
    .split(separator: " ").joined(separator: "\n"))
  exit(0)
case "list-icons":
  for item in BlipSystemIcon.allCases { print("\(item.rawValue)\t\(item.symbolName)") }
  exit(0)
case "demo":
  runDemo()
case "tuner":
  runTuner()
default:
  break
}

let options = parseOptions(arguments)
if options.preset.isEmpty { fail("missing preset (try `blip help`)") }

let content = buildContent(options)
let target = displayTarget(options.display)

if options.background, ProcessInfo.processInfo.environment["BLIP_FOREGROUND"] == nil {
  relaunchInBackground()
}

Blip.shared.runUntilDismissed {
  Blip.shared.show(content, on: target, handlers: makeHandlers(printEvents: options.events))
}

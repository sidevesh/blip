// `blip tuner`: a development window for comparing Blip with the system banner and adjusting the
// look. Not part of the library's API; it reaches the look through Blip's `Tuning` SPI.
import AppKit
@_spi(Tuning) import Blip

// MARK: - Backgrounds

/// What sits behind the banners while comparing. `wallpaper` shows nothing, so the real desktop does.
enum TunerBackground: String, CaseIterable {
  case wallpaper = "Your wallpaper"
  case stripes = "Rainbow stripes"
  case white = "White"
  case grey = "Mid grey"
  case black = "Black"
  case gradient = "Colour gradient"
  case checker = "Checkerboard"
  case bokeh = "Busy photo (bokeh)"
  case text = "Page of text"
}

final class TunerBackdropView: NSView {
  var background = TunerBackground.stripes { didSet { self.needsDisplay = true } }
  /// Vertical centres of the banner slots, from the top, for the dark guide lines on the stripes.
  var slotCentres: [CGFloat] = []

  override func draw(_ dirtyRect: NSRect) {
    let b = self.bounds
    switch self.background {
    case .wallpaper:
      NSColor.clear.setFill()
      b.fill()
    case .stripes:
      let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple, .white, .black]
      var x: CGFloat = 0, index = 0
      while x < b.width {
        colors[index % colors.count].setFill()
        NSRect(x: x, y: 0, width: 38, height: b.height).fill()
        x += 38
        index += 1
      }
      NSColor.black.setFill()
      for centre in self.slotCentres { NSRect(x: 0, y: b.height - centre - 2, width: b.width, height: 4).fill() }
    case .white:
      NSColor.white.setFill()
      b.fill()
    case .grey:
      NSColor(white: 0.5, alpha: 1).setFill()
      b.fill()
    case .black:
      NSColor.black.setFill()
      b.fill()
    case .gradient:
      NSGradient(colors: [.systemPink, .systemOrange, .systemYellow, .systemTeal, .systemIndigo])?.draw(in: b, angle: 20)
    case .checker:
      let size: CGFloat = 12
      for row in 0 ..< Int(b.height / size) + 1 {
        for column in 0 ..< Int(b.width / size) + 1 {
          ((row + column) % 2 == 0 ? NSColor.white : NSColor(white: 0.15, alpha: 1)).setFill()
          NSRect(x: CGFloat(column) * size, y: CGFloat(row) * size, width: size, height: size).fill()
        }
      }
    case .bokeh:
      NSGradient(starting: NSColor(srgbRed: 0.05, green: 0.08, blue: 0.2, alpha: 1), ending: NSColor(srgbRed: 0.35, green: 0.1, blue: 0.3, alpha: 1))?.draw(in: b, angle: 90)
      var generator = SeededGenerator(seed: 7)
      let colors: [NSColor] = [.systemYellow, .systemOrange, .white, .systemTeal, .systemPink]
      for _ in 0 ..< 70 {
        let radius = CGFloat.random(in: 6 ... 34, using: &generator)
        let center = NSPoint(x: .random(in: 0 ... b.width, using: &generator), y: .random(in: 0 ... b.height, using: &generator))
        colors.randomElement(using: &generator)!.withAlphaComponent(.random(in: 0.25 ... 0.8, using: &generator)).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
      }
    case .text:
      NSColor.white.setFill()
      b.fill()
      let words = "The quick brown fox jumps over the lazy dog while the glass banner floats above it all, bending light. "
      let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.black]
      String(repeating: words, count: 40).draw(in: b.insetBy(dx: 6, dy: 4), withAttributes: attributes)
    }
  }
}

struct SeededGenerator: RandomNumberGenerator {
  var state: UInt64
  init(seed: UInt64) { self.state = seed }
  mutating func next() -> UInt64 {
    self.state = self.state &* 6364136223846793005 &+ 1442695040888963407
    return self.state
  }
}

// MARK: - Tuner

/// Native banner slots: 64 pt tall, 12 pt apart, starting 10 pt below the menu bar.
private let slotHeight: CGFloat = 64, slotGap: CGFloat = 12

final class TunerController: NSObject, NSTextFieldDelegate {
  let window: NSWindow
  private let sliderBanner = Blip()
  private let messageBanner = Blip()
  private let backdrop = TunerBackdropView()
  private var backdropPanel: NSPanel?
  private var sliders: [NSSlider] = []
  private var fields: [NSTextField] = []
  private let status = NSTextField(labelWithString: "")
  private var overlapNative = CommandLine.arguments.contains("--overlap")
  private var showMessage = !CommandLine.arguments.contains("--no-message")
  /// `--background NAME`, NAME being a case name such as `stripes`, `white` or `bokeh`.
  private static let initialBackground: TunerBackground = {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: "--background"), index + 1 < args.count else { return .stripes }
    return TunerBackground.allCases.first { "\($0)" == args[index + 1] } ?? .stripes
  }()

  override init() {
    self.window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 700), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    super.init()
    self.window.title = "Blip tuner"
    self.window.isReleasedWhenClosed = false
    self.window.level = .floating
    NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: self.window, queue: .main) { _ in exit(0) }
    self.buildInterface()
    self.window.setFrameTopLeftPoint(NSPoint(x: 24, y: (NSScreen.screens.first?.visibleFrame.maxY ?? 900) - 12))
  }

  func start() {
    // `--set name=value,name=value` starts from those values (property names as Copy Swift prints them).
    let args = CommandLine.arguments
    if let index = args.firstIndex(of: "--set"), index + 1 < args.count {
      var style = BlipChromeStyle.current
      for pair in args[index + 1].split(separator: ",") {
        let parts = pair.split(separator: "=")
        if parts.count != 2 || Double(parts[1]) == nil || !style.set(String(parts[0]), Double(parts[1])!) { print("unknown setting \(pair)") }
      }
      BlipChromeStyle.current = style
      self.refreshControls()
    }
    self.showBackdrop()
    NSApp.activate(ignoringOtherApps: true)
    self.window.makeKeyAndOrderFront(nil)
    self.showBanners()
  }

  // MARK: Banners

  private func slotOffset(_ slot: Int) -> CGFloat { CGFloat(slot) * (slotHeight + slotGap) }

  private func showBanners() {
    var slider = BlipContent.volume(level: 0.6)
    slider.duration = 0
    slider.verticalOffset = self.slotOffset(self.overlapNative ? 0 : 1)
    self.sliderBanner.show(slider)
    if self.showMessage {
      var message = BlipContent.lowBattery()
      message.duration = 0
      message.verticalOffset = self.slotOffset(self.overlapNative ? 1 : 2)
      self.messageBanner.show(message)
    } else {
      self.messageBanner.dismiss(animated: false)
    }
  }

  private func showBackdrop() {
    guard let screen = NSScreen.screens.first else { return }
    let area = screen.visibleFrame
    let height = 10 + self.slotOffset(3) + 14
    let frame = NSRect(x: area.maxX - 293 - 34 - 40, y: area.maxY - height, width: 293 + 34 + 40, height: height)
    let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    // Just above the desktop, so the system's banner (and ours) draw on top of it. Keep the corner
    // free of other windows while comparing.
    panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
    panel.ignoresMouseEvents = true
    panel.hasShadow = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    self.backdrop.frame = NSRect(origin: .zero, size: frame.size)
    self.backdrop.slotCentres = (0 ..< 3).map { 10 + self.slotOffset($0) + slotHeight / 2 }
    panel.contentView = self.backdrop
    panel.orderFrontRegardless()
    self.backdropPanel = panel
  }

  // MARK: Interface

  private func buildInterface() {
    let rows = NSStackView()
    rows.orientation = .vertical
    rows.alignment = .leading
    rows.spacing = 6

    let picker = NSPopUpButton()
    picker.addItems(withTitles: TunerBackground.allCases.map(\.rawValue))
    picker.selectItem(withTitle: Self.initialBackground.rawValue)
    self.backdrop.background = Self.initialBackground
    picker.target = self
    picker.action = #selector(self.backgroundChanged(_:))
    rows.addArrangedSubview(self.labelled("Background", picker))

    let overlap = NSButton(checkboxWithTitle: "Overlap the native banner (off: ours sits just below it)", target: self, action: #selector(self.overlapChanged(_:)))
    overlap.state = self.overlapNative ? .on : .off
    rows.addArrangedSubview(overlap)
    let message = NSButton(checkboxWithTitle: "Also show a message banner", target: self, action: #selector(self.messageChanged(_:)))
    message.state = self.showMessage ? .on : .off
    rows.addArrangedSubview(message)
    let hint = NSTextField(wrappingLabelWithString: "Press a volume key to bring up the system's banner in the top slot.")
    hint.font = .systemFont(ofSize: 11)
    hint.textColor = .secondaryLabelColor
    rows.addArrangedSubview(hint)

    var group = ""
    for (index, entry) in BlipChromeStyle.tunables.enumerated() {
      if entry.group != group {
        group = entry.group
        let heading = NSTextField(labelWithString: group)
        heading.font = .boldSystemFont(ofSize: 12)
        rows.addArrangedSubview(heading)
      }
      rows.addArrangedSubview(self.sliderRow(entry.label, index: index, range: entry.range))
    }

    let copy = NSButton(title: "Copy Swift", target: self, action: #selector(self.copySwift))
    let reset = NSButton(title: "Reset", target: self, action: #selector(self.reset))
    let replay = NSButton(title: "Animate in again", target: self, action: #selector(self.replay))
    let buttons = NSStackView(views: [copy, reset, replay])
    rows.addArrangedSubview(buttons)
    self.status.font = .systemFont(ofSize: 11)
    self.status.textColor = .secondaryLabelColor
    self.status.maximumNumberOfLines = 0
    rows.addArrangedSubview(self.status)

    rows.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
    rows.translatesAutoresizingMaskIntoConstraints = false
    let document = NSView()
    document.translatesAutoresizingMaskIntoConstraints = false
    document.addSubview(rows)
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.drawsBackground = false
    scroll.documentView = document
    NSLayoutConstraint.activate([
      rows.topAnchor.constraint(equalTo: document.topAnchor),
      rows.leadingAnchor.constraint(equalTo: document.leadingAnchor),
      rows.trailingAnchor.constraint(equalTo: document.trailingAnchor),
      rows.bottomAnchor.constraint(equalTo: document.bottomAnchor),
      document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
    ])
    self.window.contentView = scroll
    let height = min(860, (NSScreen.screens.first?.visibleFrame.height ?? 900) - 60)
    self.window.setContentSize(NSSize(width: 460, height: height))
    self.refreshControls()
  }

  private func labelled(_ title: String, _ control: NSView) -> NSView {
    let label = NSTextField(labelWithString: title)
    label.widthAnchor.constraint(equalToConstant: 170).isActive = true
    return NSStackView(views: [label, control])
  }

  private func sliderRow(_ title: String, index: Int, range: ClosedRange<Double>) -> NSView {
    let slider = NSSlider(value: range.lowerBound, minValue: range.lowerBound, maxValue: range.upperBound, target: self, action: #selector(self.sliderMoved(_:)))
    slider.tag = index
    slider.isContinuous = true
    slider.widthAnchor.constraint(equalToConstant: 170).isActive = true
    let field = NSTextField()
    field.tag = index
    field.delegate = self
    field.widthAnchor.constraint(equalToConstant: 64).isActive = true
    self.sliders.append(slider)
    self.fields.append(field)
    let row = self.labelled(title, slider) as! NSStackView
    row.addArrangedSubview(field)
    return row
  }

  private func refreshControls() {
    for (index, entry) in BlipChromeStyle.tunables.enumerated() {
      let value = BlipChromeStyle.current[keyPath: entry.key]
      self.sliders[index].doubleValue = value
      self.fields[index].stringValue = String(format: "%.3f", value)
    }
  }

  private func set(_ index: Int, _ value: Double) {
    let entry = BlipChromeStyle.tunables[index]
    let clamped = min(max(value, entry.range.lowerBound), entry.range.upperBound)
    BlipChromeStyle.current[keyPath: entry.key] = clamped
    self.sliders[index].doubleValue = clamped
    self.fields[index].stringValue = String(format: "%.3f", clamped)
    self.showBanners()
  }

  @objc private func sliderMoved(_ sender: NSSlider) { self.set(sender.tag, sender.doubleValue) }

  func controlTextDidEndEditing(_ notification: Notification) {
    guard let field = notification.object as? NSTextField, let value = Double(field.stringValue) else { return }
    self.set(field.tag, value)
  }

  @objc private func backgroundChanged(_ sender: NSPopUpButton) {
    self.backdrop.background = TunerBackground(rawValue: sender.titleOfSelectedItem ?? "") ?? .stripes
  }

  @objc private func overlapChanged(_ sender: NSButton) {
    self.overlapNative = sender.state == .on
    self.showBanners()
  }

  @objc private func messageChanged(_ sender: NSButton) {
    self.showMessage = sender.state == .on
    self.showBanners()
  }

  @objc private func copySwift() {
    let text = BlipChromeStyle.current.changedSwift
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    self.status.stringValue = "Copied:\n" + text
    print(text)
  }

  @objc private func reset() {
    BlipChromeStyle.current = BlipChromeStyle()
    self.refreshControls()
    self.showBanners()
    self.status.stringValue = "Back to the shipped look."
  }

  @objc private func replay() {
    self.sliderBanner.dismiss(animated: false)
    self.messageBanner.dismiss(animated: false)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showBanners() }
  }
}

func runTuner() -> Never {
  var tuner: TunerController?
  Blip.shared.runUntilDismissed(exitsWhenIdle: false) {
    tuner = TunerController()
    tuner?.start()
  }
  _ = tuner
}

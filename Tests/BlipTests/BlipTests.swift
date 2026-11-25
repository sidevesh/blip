import AppKit
import XCTest
@testable import Blip

final class BlipTests: XCTestCase {
  func testEverySystemIconResolvesToASymbol() {
    for icon in BlipSystemIcon.allCases {
      XCTAssertNotNil(
        BlipIcon.system(icon).makeImage(),
        "\(icon.rawValue) → \(icon.symbolName) is not a system symbol on this macOS"
      )
    }
  }

  func testIconNamesAreUnique() {
    let names = BlipSystemIcon.allCases.map(\.rawValue)
    XCTAssertEqual(names.count, Set(names).count)
  }

  func testBatteryIconBands() {
    XCTAssertEqual(BlipSystemIcon.battery(percent: 5), .batteryEmpty)
    XCTAssertEqual(BlipSystemIcon.battery(percent: 30), .batteryLow)
    XCTAssertEqual(BlipSystemIcon.battery(percent: 50), .batteryHalf)
    XCTAssertEqual(BlipSystemIcon.battery(percent: 70), .batteryHigh)
    XCTAssertEqual(BlipSystemIcon.battery(percent: 100), .batteryFull)
    XCTAssertEqual(BlipSystemIcon.battery(percent: 50, charging: true), .batteryCharging)
  }

  func testMutedVolumeShowsZeroLevelAndSlashedSpeaker() {
    let content = BlipContent.volume(level: 0.6, muted: true)
    XCTAssertEqual(content.level, 0)
    guard case let .system(icon)? = content.leadingIcon else { return XCTFail("expected a system icon") }
    XCTAssertEqual(icon, .volumeMuted)
  }

  func testNativeBannerTitlesAndLayouts() {
    XCTAssertEqual(BlipContent.volume(level: 0.5).title, "Sound")
    XCTAssertEqual(BlipContent.keyboardBrightness(level: 0.5).title, "Keyboard Brightness")
    XCTAssertEqual(BlipContent.lowBattery().layout, .message)
    XCTAssertEqual(BlipContent.lowBattery().title, "Low Battery")
    XCTAssertEqual(BlipContent.lowBattery().message, "Plug in soon to recharge")
    XCTAssertEqual(BlipContent.charging(timeUntilFull: "1:20").message, "1:20 until fully charged")
    XCTAssertEqual(BlipContent.accessory(name: "AirPods", batteryPercent: 80).message, "80% Battery")
    XCTAssertEqual(BlipContent.accessory(name: "Keyboard").message, "Connected")
    XCTAssertEqual(BlipContent.focus(on: true).message, "On")
  }

  func testAppearanceReadsAValidTintAmount() {
    let appearance = BlipAppearance.current
    XCTAssertGreaterThanOrEqual(appearance.glassTintAmount, 0)
    XCTAssertLessThanOrEqual(appearance.glassTintAmount, 1)
  }

  func testAppearanceObservationCanBeStopped() {
    let token = BlipAppearance.observe { _ in }
    BlipAppearance.stopObserving(token)
  }

  func testBackdropFiltersAreAvailableOnThisSystem() throws {
    try XCTSkipUnless(BackdropBlurView.isAvailable, "this macOS lacks the CoreAnimation backdrop filters")
    XCTAssertNotNil(BackdropBlurView.makeFilter(type: "gaussianBlur"))
  }

  func testCustomImageIsReturnedAsIs() {
    let image = NSImage(size: NSSize(width: 4, height: 4))
    XCTAssertTrue(BlipIcon.image(image).makeImage() === image)
  }

  /// The system's banners always have a second row, a slider or a line of text; no preset may show a
  /// title alone.
  func testEveryMessagePresetHasTwoLines() {
    let presets: [BlipContent] = [
      .microphone(muted: false), .microphone(muted: true), .allMicrophones(muted: true), .lowBattery(),
      .charging(), .charging(timeUntilFull: "1:20"), .lowPowerMode(), .battery(percent: 80), .accessory(name: "AirPods"),
      .listeningMode("Transparency"), .focus(on: true), .camera(on: false), .capsLock(on: true), .wifi(on: true),
      .bluetooth(on: true), .bluetooth(on: false), .airplaneMode(on: true), .notifications(on: false), .screenLock(locked: true),
      .media(.play), .media(.pause), .media(.playPause), .media(.next), .media(.previous),
      .dpi(1600), .smartShift(freeSpin: true), .easySwitch(channel: 2), .scrollDirection(natural: true),
      .status(.success, title: "Saved", message: "Settings applied"), .screenshot(), .clipboardCopied(),
    ]
    for content in presets where content.layout == .message {
      XCTAssertFalse(content.title.isEmpty, "\(content.title)")
      XCTAssertFalse((content.message ?? "").isEmpty, "\(content.title) has no second line")
    }
  }

  func testBluetoothUsesTheSystemLogo() {
    XCTAssertNotNil(BlipIcon.system(.bluetooth).makeImage())
    XCTAssertNotNil(BlipIcon.system(.bluetoothOff).makeImage())
  }
}

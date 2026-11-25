import AppKit

/// The measured look of a banner and its small controls (the hover close button, the slider knob,
/// the animation). Fitted to the system banner and fixed: nothing here is configurable.
@_spi(Tuning) public struct BlipChromeStyle: Equatable {
  @_spi(Tuning) public init() {}

  /// Diameter of the close button in points.
  var closeSize = 18.0
  /// How far the close button sits out past the banner's top-left corner, in points (moves it up and left).
  var closeOutset = 2.4
  /// How long the close button takes to fade in and out, in seconds.
  var closeFade = 0.35
  /// Opacity of the white cross, 0...1.
  var closeCrossAlpha = 0.62
  /// Stroke width of the cross in points.
  var closeCrossWidth = 1.25
  /// Cross arm inset from the disc's edge, as a fraction of its diameter.
  var closeCrossInset = 0.325
  /// Opacity of the red-orange disc, 0...1.
  var closeTintAlpha = 0.79
  /// Strength of the blur under the disc, in points of radius.
  var closeBlur = 6.0
  /// Rim around the disc: its width in points, how bright it is (0 black, 1 white) and its opacity.
  var closeRimWidth = 0.5
  var closeRimRed = 172.0
  var closeRimGreen = 51.0
  var closeRimBlue = 42.0
  var closeRimAlpha = 0.9
  /// 1 draws the disc as real glass, like the system's (its close button is a regular glass circle
  /// with an 18 point frame and a 9 point semibold xmark), tinted with the disc colour; 0 builds it
  /// from a blur and a flat tint instead.
  var closeGlass = 1.0
  /// The disc's colour, 0...255 per channel.
  var closeTintRed = 247.0
  var closeTintGreen = 125.0
  var closeTintBlue = 80.0
  /// Opacity of the disc's shadow, 0...1.
  var closeShadow = 0.15

  /// Slider knob opacity while hovered and while held or dragged, 0...1.
  var knobAlpha = 0.88
  var knobDragAlpha = 0.0
  /// Knob shadow opacity while hovered and while held, 0...1.
  var knobShadow = 0.22
  var knobDragShadow = 0.4
  /// Knob shadow blur radius while hovered and while held, in points.
  var knobShadowBlur = 4.0
  var knobDragShadowBlur = 7.0
  /// Brightness of the knob's thin rim while held, 0...1.
  var knobDragRim = 0.25
  /// Size of the held knob in points (the resting one is 18.5 by 13.5).
  var knobHeldWidth = 22.9
  var knobHeldHeight = 17.5
  /// How far in from each side the held knob's shadow starts, so it is no wider than the knob.
  var knobDragShadowInset = 2.5
  /// Opacity of the glass over the held knob, 0...1; lower shows less of its refraction and shine.
  var knobGlassAlpha = 0.3
  /// The glass variant used for the held knob (0 is the plain one).
  var knobGlassVariant = 11.0
  /// 1 uses the clear glass style (less frosting), 0 the regular one.
  var knobGlassClear = 1.0
  /// How far the held knob's shadow falls below it, in points.
  var knobDragShadowOffset = 6.0

  /// Banner slide: 0 from the top, 1 from the bottom, 2 from the left, 3 from the right.
  var animDirection = 0.0
  /// How far the banner travels while appearing or leaving, in points.
  var animDistance = 10.0
  /// The system banner animates with SwiftUI's spring(response: 0.48669, dampingFraction: 1), found
  /// in ControlCenter. Response is the spring's period in seconds, damping 1 is no bounce.
  var animResponse = 0.48669
  var animDamping = 1.0
  /// Size the banner grows from when it appears and shrinks to when it leaves, as a fraction of its
  /// full width and height (1 = no change). It stays pinned at its top centre.
  var animScaleX = 0.94
  var animScaleY = 0.9
  /// 1 fades the banner as it slides, 0 slides it at full opacity.
  var animFade = 1.0

  /// How far in from the banner's edge the blur under the glass stops, in points. At 0 the blur
  /// reaches the edge and the glass's rim refracts blurred content; a few points lets the rim
  /// refract the sharp backdrop, as the system banner does at high tint.
  var glassBlurInset = 0.0

  /// A dark band along the top and bottom edges that tones down the glass's own white shine there
  /// (the system banner has none). Height in points and darkest opacity; it scales with the lensing.
  var cancelBandHeight = 6.0
  var cancelBandAlpha = 0.0
  /// The system banner's edge light, drawn by Blip: a white hairline along the top and bottom edges
  /// (opacity rimWhite) with a dim glow inside it (rimGlow, a fraction of rimWhite), and a dark
  /// hairline along the left and right (rimDark). Width is in points.
  var rimWhite = 0.45
  var rimGlow = 0.45
  var rimDark = 0.85
  var rimWidth = 0.5
  /// How far in from each end, as a fraction of the width, the white hairline fades out.
  var rimSideFade = 0.15
  /// How much of the hairline is left at the very ends, 0...1.
  var rimSideFloor = 0.65
  /// A soft light just inside the top and bottom edges: height in points and opacity at the edge.
  var innerGlowHeight = 7.0
  var innerGlowAlpha = 0.07
  /// Shifts to the fill's tone curve (scale and bias), on top of the fitted values.
  var fillScaleAdjust = 0.0
  var fillBiasAdjust = -0.035
  var fillSaturationAdjust = 0.0
  /// Added to the blur under the glass, in points (normally none: the glass filter blurs).
  var blurAdjust = 0.0
  /// How strongly the glass view is drawn, 0...1.
  var glassLensing = 1.0
  /// Nudges the banner from its measured position, in points (+x right, +y down).
  var positionX = 0.0
  var positionY = 0.0
  /// The glass's lensing fades out as the Liquid Glass tint rises from `lensFadeStart` to
  /// `lensFadeEnd`; the system banner looks like lensing 0 at the highest tint.
  var lensFadeStart = 0.5
  var lensFadeEnd = 1.0
  /// The thin ring drawn along the banner's edge over the glass. Brightness 0 is a dark ring that
  /// tones down the glass's bright rim; 1 is a white one, like the system banner's rim at high tint.
  /// Alpha scales the ring, width is each ring's thickness in points, and amount keeps the ring
  /// showing even when the glass rim is left on (gleam 1).
  var edgeBrightness = 0.0
  var edgeAlpha = 1.0
  var edgeWidth = 1.0
  var edgeAmount = 0.0
  /// Values written into the glass view's private `glassBackground` filter (a CABackdropLayer deep
  /// inside NSGlassEffectView): the refraction along the edge, and the blur, which the filter applies
  /// past the refracting band so the edge bends the sharp background as the system banner's does.
  /// Apple's refraction defaults are -50, 20, 10, 16; the blur scales with the Liquid Glass tint.
  var glassFilterBlur = 2.06
  var glassInnerRefraction = -50.0
  var glassInnerRefractionHeight = 20.0
  var glassOuterRefraction = 10.0
  var glassOuterRefractionHeight = 16.0
  /// 1 hides the glass's own edge shading, two `vibrantColorMatrix` SDF layers named `@2` and `@3`:
  /// `@3` lights the top and bottom of the straight middle section, which reads as a bright
  /// rectangle, and `@2` darkens the rounded ends. RimView draws the system banner's edge light instead.
  var glassHideEdgeLight = 1.0
  /// The glass view's other private switches, for finding the combination that draws no top and
  /// bottom shine: `_subduedState`, `_scrimState`, `_contentLensing`, `_adaptiveAppearance`
  /// (0...3 each), `_subvariant` (0...20, 0 = none), and the on/off `_tintOpacityReduced`,
  /// `_useReducedShadowRadius` and `_inverseMeshed`. The defaults are the glass's own.
  var glassSubdued = 0.0
  var glassScrim = 0.0
  var glassContentLensing = 0.0
  var glassAdaptive = 2.0
  var glassSubvariant = 0.0
  var glassReducedTint = 0.0
  var glassReducedShadow = 0.0
  var glassInverseMeshed = 0.0
  /// For tuning the banner glass: its private variant (0...20) and whether it uses the clear style.
  var bannerVariant = 11.0
  var bannerClear = 0.0
  /// For tuning: a glass tint to show the banners with, 0...1, or below 0 to follow the system setting.
  var previewTint = -1.0

  /// Keeps the close button and the held knob showing, for comparing them with the system's.
  var pinPreview = false

  @_spi(Tuning) public static var current = BlipChromeStyle() {
    didSet { NotificationCenter.default.post(name: .blipChromeStyleChanged, object: nil) }
  }

  /// The values the tuner offers: (group, label, key, range).
  @_spi(Tuning) public static let tunables: [(group: String, label: String, key: WritableKeyPath<BlipChromeStyle, Double>, range: ClosedRange<Double>)] = [
    ("Fill", "Saturation +/-", \.fillSaturationAdjust, -1 ... 1),
    ("Fill", "Brightness scale +/-", \.fillScaleAdjust, -0.5 ... 0.5),
    ("Fill", "Lift +/- (lower = less glow)", \.fillBiasAdjust, -0.2 ... 0.2),
    ("Fill", "Blur +/- (points)", \.blurAdjust, -2 ... 12),
    ("Fill", "Liquid Glass tint (-1 = system)", \.previewTint, -1 ... 1),
    ("Rim", "White hairline", \.rimWhite, 0 ... 1),
    ("Rim", "Glow inside it", \.rimGlow, 0 ... 1),
    ("Rim", "Width (points)", \.rimWidth, 0.25 ... 2),
    ("Rim", "Fade toward ends", \.rimSideFade, 0 ... 0.5),
    ("Rim", "Left at the ends", \.rimSideFloor, 0 ... 1),
    ("Rim", "Dark side hairline", \.rimDark, 0 ... 1),
    ("Inner light", "Height (points)", \.innerGlowHeight, 0 ... 20),
    ("Inner light", "Opacity", \.innerGlowAlpha, 0 ... 0.3),
    ("Glass", "Glass strength", \.glassLensing, 0 ... 1),
    ("Glass", "Blur in the glass", \.glassFilterBlur, 0 ... 30),
    ("Glass", "Inner refraction", \.glassInnerRefraction, -150 ... 50),
    ("Glass", "Inner refraction height", \.glassInnerRefractionHeight, 0 ... 40),
    ("Glass", "Outer refraction", \.glassOuterRefraction, -50 ... 50),
    ("Glass", "Outer refraction height", \.glassOuterRefractionHeight, 0 ... 40),
    ("Glass", "Hide Apple's edge light (1 = hidden)", \.glassHideEdgeLight, 0 ... 1),
    ("Glass", "Variant (private)", \.bannerVariant, 0 ... 20),
    ("Position", "X (+ right)", \.positionX, -20 ... 20),
    ("Position", "Y (+ down)", \.positionY, -20 ... 20),
  ]

  /// Sets a tunable by its property name, for `blip tuner --set name=value`.
  @_spi(Tuning) public mutating func set(_ name: String, _ value: Double) -> Bool {
    guard let entry = Self.tunables.first(where: { "\($0.key)".components(separatedBy: ".").last == name }) else { return false }
    self[keyPath: entry.key] = value
    return true
  }

  /// The tunables that differ from the shipped defaults, as Swift to paste back into this file.
  @_spi(Tuning) public var changedSwift: String {
    let defaults = BlipChromeStyle()
    let lines = Self.tunables.compactMap { entry -> String? in
      let value = self[keyPath: entry.key]
      guard abs(value - defaults[keyPath: entry.key]) > 0.0005 else { return nil }
      let name = "\(entry.key)".components(separatedBy: ".").last ?? "?"
      return "var \(name) = \((value * 1000).rounded() / 1000)"
    }
    return lines.isEmpty ? "(no changes)" : lines.joined(separator: "\n")
  }
}

extension Notification.Name {
  static let blipChromeStyleChanged = Notification.Name("BlipChromeStyleChanged")
}

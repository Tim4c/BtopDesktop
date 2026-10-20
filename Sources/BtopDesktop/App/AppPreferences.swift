import Foundation

@MainActor
final class AppPreferences {
  private enum Key {
    static let activeGrayscaleEnabled = "activeGrayscaleEnabled"
    static let inactiveGrayscaleEnabled = "inactiveGrayscaleEnabled"
    static let inactiveOpacity = "inactiveOpacity"
    static let activeOpacity = "activeOpacity"
    static let interactiveMode = "interactiveMode"
    static let panelWidthRatio = "panelWidthRatio"
    static let panelHeightRatio = "panelHeightRatio"
    static let panelHorizontalAnchor = "panelHorizontalAnchor"
    static let panelVerticalAnchor = "panelVerticalAnchor"
    static let activeBorderColor = "activeBorderColor"
    static let inactiveBorderColor = "inactiveBorderColor"
    static let panelCornerRadius = "panelCornerRadius"
    static let activeBorderEnabled = "activeBorderEnabled"
    static let inactiveBorderEnabled = "inactiveBorderEnabled"
    static let dimensionsLinked = "dimensionsLinked"
    static let fontSize = "fontSize"
    static let hideDesktopIcons = "hideDesktopIcons"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let panel = PanelPreferences()
    defaults.register(defaults: [
      Key.activeGrayscaleEnabled: panel.activeGrayscaleEnabled,
      Key.inactiveGrayscaleEnabled: panel.inactiveGrayscaleEnabled,
      Key.activeOpacity: panel.activeOpacity,
      Key.inactiveOpacity: panel.inactiveOpacity,
      Key.panelWidthRatio: panel.panelWidthRatio,
      Key.panelHeightRatio: panel.panelHeightRatio,
      Key.panelHorizontalAnchor: panel.panelHorizontalAnchor,
      Key.panelVerticalAnchor: panel.panelVerticalAnchor,
      Key.activeBorderColor: panel.activeBorderColor,
      Key.inactiveBorderColor: panel.inactiveBorderColor,
      Key.panelCornerRadius: panel.panelCornerRadius,
      Key.activeBorderEnabled: panel.activeBorderEnabled,
      Key.inactiveBorderEnabled: panel.inactiveBorderEnabled,
      Key.dimensionsLinked: panel.dimensionsLinked,
      Key.fontSize: panel.fontSize,
      Key.interactiveMode: false,
      Key.hideDesktopIcons: false
    ])
  }

  var activeGrayscaleEnabled: Bool {
    get { defaults.bool(forKey: Key.activeGrayscaleEnabled) }
    set { defaults.set(newValue, forKey: Key.activeGrayscaleEnabled) }
  }

  var inactiveGrayscaleEnabled: Bool {
    get { defaults.bool(forKey: Key.inactiveGrayscaleEnabled) }
    set { defaults.set(newValue, forKey: Key.inactiveGrayscaleEnabled) }
  }

  var inactiveOpacity: CGFloat {
    get {
      validated(
        defaults.double(forKey: Key.inactiveOpacity), range: 0.1...1, fallback: PanelPreferences().inactiveOpacity)
    }
    set {
      let value = validated(Double(newValue), range: 0.1...1, fallback: PanelPreferences().inactiveOpacity)
      defaults.set(Double(value), forKey: Key.inactiveOpacity)
    }
  }

  var activeOpacity: CGFloat {
    get {
      validated(
        defaults.double(forKey: Key.activeOpacity), range: 0.1...1, fallback: PanelPreferences().activeOpacity)
    }
    set {
      let value = validated(Double(newValue), range: 0.1...1, fallback: PanelPreferences().activeOpacity)
      defaults.set(Double(value), forKey: Key.activeOpacity)
    }
  }

  var interactiveMode: Bool {
    get { defaults.bool(forKey: Key.interactiveMode) }
    set { defaults.set(newValue, forKey: Key.interactiveMode) }
  }

  /// Ratios are deliberately stored rather than point values so the layout
  /// remains correct when the display resolution changes.
  var panelWidthRatio: CGFloat {
    get {
      validated(
        defaults.double(forKey: Key.panelWidthRatio), range: 0.3...1, fallback: PanelPreferences().panelWidthRatio)
    }
    set {
      let value = validated(Double(newValue), range: 0.3...1, fallback: PanelPreferences().panelWidthRatio)
      defaults.set(Double(value), forKey: Key.panelWidthRatio)
    }
  }

  var panelHeightRatio: CGFloat {
    get {
      validated(
        defaults.double(forKey: Key.panelHeightRatio), range: 0.3...1, fallback: PanelPreferences().panelHeightRatio)
    }
    set {
      let value = validated(Double(newValue), range: 0.3...1, fallback: PanelPreferences().panelHeightRatio)
      defaults.set(Double(value), forKey: Key.panelHeightRatio)
    }
  }

  /// Grid coordinates: 0 = leading/bottom, 1 = centre, 2 = trailing/top.
  var panelHorizontalAnchor: Int {
    get { max(0, min(2, defaults.integer(forKey: Key.panelHorizontalAnchor))) }
    set { defaults.set(max(0, min(2, newValue)), forKey: Key.panelHorizontalAnchor) }
  }

  var panelVerticalAnchor: Int {
    get { max(0, min(2, defaults.integer(forKey: Key.panelVerticalAnchor))) }
    set { defaults.set(max(0, min(2, newValue)), forKey: Key.panelVerticalAnchor) }
  }

  var activeBorderColor: String {
    get {
      validatedColor(
        defaults.string(forKey: Key.activeBorderColor), fallback: PanelPreferences().activeBorderColor)
    }
    set {
      defaults.set(
        validatedColor(newValue, fallback: PanelPreferences().activeBorderColor),
        forKey: Key.activeBorderColor)
    }
  }

  var inactiveBorderColor: String {
    get {
      validatedColor(
        defaults.string(forKey: Key.inactiveBorderColor), fallback: PanelPreferences().inactiveBorderColor)
    }
    set {
      defaults.set(
        validatedColor(newValue, fallback: PanelPreferences().inactiveBorderColor),
        forKey: Key.inactiveBorderColor)
    }
  }

  var panelCornerRadius: CGFloat {
    get {
      validated(
        defaults.double(forKey: Key.panelCornerRadius), range: 0...30, fallback: PanelPreferences().panelCornerRadius)
    }
    set {
      let value = validated(Double(newValue), range: 0...30, fallback: PanelPreferences().panelCornerRadius)
      defaults.set(Double(value), forKey: Key.panelCornerRadius)
    }
  }

  var activeBorderEnabled: Bool {
    get { defaults.bool(forKey: Key.activeBorderEnabled) }
    set { defaults.set(newValue, forKey: Key.activeBorderEnabled) }
  }

  var inactiveBorderEnabled: Bool {
    get { defaults.bool(forKey: Key.inactiveBorderEnabled) }
    set { defaults.set(newValue, forKey: Key.inactiveBorderEnabled) }
  }

  var dimensionsLinked: Bool {
    get { defaults.bool(forKey: Key.dimensionsLinked) }
    set { defaults.set(newValue, forKey: Key.dimensionsLinked) }
  }

  var hideDesktopIcons: Bool {
    get { defaults.bool(forKey: Key.hideDesktopIcons) }
    set { defaults.set(newValue, forKey: Key.hideDesktopIcons) }
  }

}

extension AppPreferences {
  var fontSize: CGFloat {
    get { validated(defaults.double(forKey: Key.fontSize), range: 10...20, fallback: 12).rounded() }
    set { defaults.set(Double(validated(Double(newValue), range: 10...20, fallback: 12).rounded()),
                       forKey: Key.fontSize) }
  }

  var panelSettings: PanelPreferences {
    get {
      var panel = PanelPreferences()
      panel.activeGrayscaleEnabled = activeGrayscaleEnabled
      panel.inactiveGrayscaleEnabled = inactiveGrayscaleEnabled
      panel.activeOpacity = activeOpacity
      panel.inactiveOpacity = inactiveOpacity
      panel.panelWidthRatio = panelWidthRatio
      panel.panelHeightRatio = panelHeightRatio
      panel.panelHorizontalAnchor = panelHorizontalAnchor
      panel.panelVerticalAnchor = panelVerticalAnchor
      panel.activeBorderColor = activeBorderColor
      panel.inactiveBorderColor = inactiveBorderColor
      panel.panelCornerRadius = panelCornerRadius
      panel.activeBorderEnabled = activeBorderEnabled
      panel.inactiveBorderEnabled = inactiveBorderEnabled
      panel.dimensionsLinked = dimensionsLinked
      panel.fontSize = fontSize
      return panel
    }
    set {
      activeGrayscaleEnabled = newValue.activeGrayscaleEnabled
      inactiveGrayscaleEnabled = newValue.inactiveGrayscaleEnabled
      activeOpacity = newValue.activeOpacity
      inactiveOpacity = newValue.inactiveOpacity
      panelWidthRatio = newValue.panelWidthRatio
      panelHeightRatio = newValue.panelHeightRatio
      panelHorizontalAnchor = newValue.panelHorizontalAnchor
      panelVerticalAnchor = newValue.panelVerticalAnchor
      activeBorderColor = newValue.activeBorderColor
      inactiveBorderColor = newValue.inactiveBorderColor
      panelCornerRadius = newValue.panelCornerRadius
      activeBorderEnabled = newValue.activeBorderEnabled
      inactiveBorderEnabled = newValue.inactiveBorderEnabled
      dimensionsLinked = newValue.dimensionsLinked
      fontSize = newValue.fontSize
    }
  }

  func restorePanelDefaults() {
    panelSettings = PanelPreferences()
  }

  private func validated(_ value: Double, range: ClosedRange<Double>, fallback: CGFloat) -> CGFloat {
    guard value.isFinite else { return fallback }
    return CGFloat(max(range.lowerBound, min(range.upperBound, value)))
  }

  private func validatedColor(_ value: String?, fallback: String) -> String {
    guard let value else { return fallback }
    let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard hex.count == 6, hex.allSatisfy({ "0123456789abcdefABCDEF".contains($0) }) else { return fallback }
    return hex.uppercased()
  }
}

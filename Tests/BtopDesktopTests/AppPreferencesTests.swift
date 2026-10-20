import XCTest
@testable import BtopDesktop

final class AppPreferencesTests: XCTestCase {
  @MainActor func testRegistrationAndResetShareDefaults() {
    let preferences = AppPreferences(defaults: MemoryDefaults())
    XCTAssertEqual(preferences.panelSettings, PanelPreferences())
    preferences.interactiveMode = true
    preferences.hideDesktopIcons = true
    preferences.activeOpacity = 0.4
    preferences.panelHorizontalAnchor = 2
    preferences.dimensionsLinked = true
    preferences.restorePanelDefaults()
    XCTAssertEqual(preferences.panelSettings, PanelPreferences())
    XCTAssertTrue(preferences.interactiveMode)
    XCTAssertTrue(preferences.hideDesktopIcons)
  }

  @MainActor func testExistingPreferencesArePreservedAndSnapshotsRoundTrip() {
    let defaults = MemoryDefaults()
    defaults.set(0.6, forKey: "activeOpacity")
    defaults.set(2, forKey: "panelVerticalAnchor")
    let preferences = AppPreferences(defaults: defaults)
    XCTAssertEqual(preferences.activeOpacity, 0.6)
    XCTAssertEqual(preferences.panelVerticalAnchor, 2)
    var panel = preferences.panelSettings
    panel.panelWidthRatio = 0.9
    panel.inactiveBorderEnabled = true
    preferences.panelSettings = panel
    XCTAssertEqual(preferences.panelSettings, panel)
  }

  @MainActor func testFontSizeRejectsInvalidValuesAndRoundsToWholePoints() {
    let preferences = AppPreferences(defaults: MemoryDefaults())
    preferences.fontSize = .nan
    XCTAssertEqual(preferences.fontSize, 12)
    preferences.fontSize = 2
    XCTAssertEqual(preferences.fontSize, 10)
    preferences.fontSize = 30
    XCTAssertEqual(preferences.fontSize, 20)
    preferences.fontSize = 15.6
    XCTAssertEqual(preferences.fontSize, 16)
  }

  @MainActor func testInvalidStoredValuesCannotBreakLayout() {
    let defaults = MemoryDefaults()
    defaults.set(-100, forKey: "panelWidthRatio")
    defaults.set(100, forKey: "panelCornerRadius")
    defaults.set("invalid", forKey: "activeBorderColor")
    let preferences = AppPreferences(defaults: defaults)
    XCTAssertEqual(preferences.panelWidthRatio, 0.3)
    XCTAssertEqual(preferences.panelCornerRadius, 30)
    XCTAssertEqual(preferences.activeBorderColor, PanelPreferences().activeBorderColor)
    preferences.panelHeightRatio = .nan
    preferences.activeOpacity = .infinity
    preferences.panelHorizontalAnchor = 9
    preferences.inactiveBorderColor = "#abcdef"
    XCTAssertEqual(preferences.panelHeightRatio, PanelPreferences().panelHeightRatio)
    XCTAssertEqual(preferences.activeOpacity, PanelPreferences().activeOpacity)
    XCTAssertEqual(preferences.panelHorizontalAnchor, 2)
    XCTAssertEqual(preferences.inactiveBorderColor, "ABCDEF")
  }
}

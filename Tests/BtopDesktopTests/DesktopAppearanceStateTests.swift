import XCTest
@testable import BtopDesktop

final class DesktopAppearanceStateTests: XCTestCase {
  func testWallpaperRejectsFocusWithoutPreview() {
    let state = DesktopAppearanceState()
    XCTAssertFalse(state.isActive(hasExplicitClickFocus: true, isKeyWindow: true))
  }

  func testInteractiveAppearanceRequiresClickAndKeyWindow() {
    var state = DesktopAppearanceState()
    state.mode = .interactive
    XCTAssertFalse(state.isActive(hasExplicitClickFocus: false, isKeyWindow: true))
    XCTAssertFalse(state.isActive(hasExplicitClickFocus: true, isKeyWindow: false))
    XCTAssertTrue(state.isActive(hasExplicitClickFocus: true, isKeyWindow: true))
  }

  func testPreviewOverridesFocusAndEndsCleanly() {
    var state = DesktopAppearanceState()
    state.preview = .appearance(active: true)
    XCTAssertTrue(state.isActive(hasExplicitClickFocus: false, isKeyWindow: false))
    state.previewCornerRadius()
    XCTAssertTrue(state.isActive(hasExplicitClickFocus: false, isKeyWindow: false))
    XCTAssertTrue(state.showsGuide(configuredBorder: false))
    XCTAssertFalse(state.showsGuide(configuredBorder: true))
    state.clearTransientState()
    XCTAssertFalse(state.isActive(hasExplicitClickFocus: false, isKeyWindow: false))
    XCTAssertFalse(state.showsGuide(configuredBorder: false))
  }

  func testAutomaticResizeNeverAddsGuide() {
    var state = DesktopAppearanceState()
    state.resize = .automatic
    XCTAssertFalse(state.showsGuide(configuredBorder: false))
    state.resize = .manual
    XCTAssertTrue(state.showsGuide(configuredBorder: false))
    state.clearTransientState()
    XCTAssertFalse(state.showsGuide(configuredBorder: false))
  }

  func testThemePreviewShowsColorsWithoutActivatingPanelOrAddingGuide() {
    var state = DesktopAppearanceState()
    state.preview = .theme
    XCTAssertFalse(state.grayscaleEnabled(configured: true))
    XCTAssertFalse(state.grayscaleEnabled(configured: false))
    XCTAssertFalse(state.isActive(hasExplicitClickFocus: false, isKeyWindow: false))
    XCTAssertFalse(state.showsGuide(configuredBorder: false))
    state.clearTransientState()
    XCTAssertTrue(state.grayscaleEnabled(configured: true))
    XCTAssertFalse(state.grayscaleEnabled(configured: false))
  }

  func testInactivePreviewRemainsInactiveWhileFocused() {
    var state = DesktopAppearanceState()
    state.mode = .interactive
    state.preview = .appearance(active: false)
    state.previewCornerRadius()
    XCTAssertFalse(state.isActive(hasExplicitClickFocus: true, isKeyWindow: true))
  }
}

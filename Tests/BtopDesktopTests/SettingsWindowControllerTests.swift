import AppKit
import XCTest
@testable import BtopDesktop

@MainActor
private final class SettingsRecorder {
  var changes: [Bool] = []
  var previews: [Bool] = []
  var ended = 0
  var closed = 0
  var cornerPreviews = 0
  var allowsDesktopChange = false

  func controller(preferences: AppPreferences) -> SettingsWindowController {
    SettingsWindowController(
      preferences: preferences,
      onChange: { self.changes.append($0) },
      onLayoutInteractionEnded: {}, onLayoutInteractionBegan: {},
      onAppearancePreview: { self.previews.append($0) },
      onAppearancePreviewEnded: { self.ended += 1 },
      onCornerRadiusPreview: { self.cornerPreviews += 1 },
      onDesktopIconsChanged: { _ in self.allowsDesktopChange },
      onSettingsClosed: { self.closed += 1 })
  }
}

final class SettingsWindowControllerTests: XCTestCase {
  @MainActor func testLinkedDimensionsPositionAndReset() throws {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let preferences = AppPreferences(defaults: MemoryDefaults())
    preferences.interactiveMode = true
    let recorder = SettingsRecorder()
    let controller = recorder.controller(preferences: preferences)
    let form = try XCTUnwrap(controller.window?.contentView as? SettingsView)
    form.toggleDimensionsLink()
    XCTAssertTrue(preferences.dimensionsLinked)
    form.controls.width.doubleValue = 90
    form.valueChanged(form.controls.width)
    XCTAssertEqual(preferences.panelWidthRatio, 0.9, accuracy: 0.001)
    XCTAssertEqual(preferences.panelHeightRatio, 0.66, accuracy: 0.001)
    XCTAssertEqual(recorder.changes, [true])
    form.selectPosition(form.controls.positionButtons[2])
    XCTAssertEqual(preferences.panelHorizontalAnchor, 2)
    XCTAssertEqual(preferences.panelVerticalAnchor, 2)
    form.restoreDefaults()
    XCTAssertEqual(preferences.panelSettings, PanelPreferences())
    XCTAssertTrue(preferences.interactiveMode)
    XCTAssertEqual(form.controls.width.doubleValue, 75)
    XCTAssertEqual(form.controls.height.doubleValue, 55, accuracy: 0.001)
  }

  @MainActor func testFontSizeIsSavedReloadedAndReset() throws {
    let defaults = MemoryDefaults()
    let preferences = AppPreferences(defaults: defaults)
    let recorder = SettingsRecorder()
    let controller = recorder.controller(preferences: preferences)
    let form = try XCTUnwrap(controller.window?.contentView as? SettingsView)
    form.layoutSubtreeIfNeeded()
    let scroll = try XCTUnwrap(form.subviews.first as? NSScrollView)
    let document = try XCTUnwrap(scroll.documentView)
    XCTAssertGreaterThan(document.fittingSize.height, 0)
    XCTAssertTrue(scroll.hasVerticalScroller)
    XCTAssertEqual(form.controls.fontSize.doubleValue, 12)
    form.controls.fontSize.doubleValue = 18
    form.valueChanged(form.controls.fontSize)
    XCTAssertEqual(preferences.fontSize, 18)
    XCTAssertEqual(AppPreferences(defaults: defaults).fontSize, 18)
    XCTAssertEqual(recorder.changes, [false])
    XCTAssertTrue(recorder.previews.isEmpty)
    form.restoreDefaults()
    XCTAssertEqual(preferences.fontSize, 12)
    XCTAssertEqual(form.controls.fontSize.doubleValue, 12)
  }

  @MainActor func testAppearanceAndCornerPreviewEndWhenSettingsClose() throws {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let preferences = AppPreferences(defaults: MemoryDefaults())
    let recorder = SettingsRecorder()
    let controller = recorder.controller(preferences: preferences)
    let form = try XCTUnwrap(controller.window?.contentView as? SettingsView)
    form.controls.activeOpacity.doubleValue = 0.5
    form.valueChanged(form.controls.activeOpacity)
    XCTAssertEqual(preferences.activeOpacity, 0.5)
    XCTAssertEqual(recorder.previews, [true])
    form.controls.cornerRadius.doubleValue = 18
    form.valueChanged(form.controls.cornerRadius)
    XCTAssertEqual(preferences.panelCornerRadius, 18)
    XCTAssertEqual(recorder.cornerPreviews, 1)
    XCTAssertEqual(recorder.previews, [true, true])
    controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    XCTAssertEqual(recorder.ended, 1)
    XCTAssertEqual(recorder.closed, 1)
    XCTAssertEqual(form.controls.activeModeTitle.stringValue, "ACTIVE MODE")
  }

  @MainActor func testDesktopIconFailureRollsBackControlAndPreference() async throws {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let preferences = AppPreferences(defaults: MemoryDefaults())
    let recorder = SettingsRecorder()
    let controller = recorder.controller(preferences: preferences)
    let form = try XCTUnwrap(controller.window?.contentView as? SettingsView)
    form.controls.hideDesktopIcons.state = .on
    form.valueChanged(form.controls.hideDesktopIcons)
    XCTAssertFalse(form.controls.hideDesktopIcons.isEnabled)
    await controller.desktopIconChangeTask?.value
    XCTAssertTrue(form.controls.hideDesktopIcons.isEnabled)
    XCTAssertFalse(preferences.hideDesktopIcons)
    XCTAssertEqual(form.controls.hideDesktopIcons.state, .off)
    recorder.allowsDesktopChange = true
    form.controls.hideDesktopIcons.state = .on
    form.valueChanged(form.controls.hideDesktopIcons)
    await controller.desktopIconChangeTask?.value
    XCTAssertTrue(preferences.hideDesktopIcons)
    form.restoreDefaults()
    await controller.desktopIconChangeTask?.value
    XCTAssertFalse(preferences.hideDesktopIcons)
  }
}

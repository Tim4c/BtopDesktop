import AppKit
import XCTest
@testable import BtopDesktop

final class SettingsThemeSelectionTests: XCTestCase {
  @MainActor func testThemeCardAppliesSelectionAndRestoreKeepsIt() async throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let configuration = BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory))
    let store = BtopThemeStore(configurationStore: configuration, bundledThemes: fixture.directory)
    let source = fixture.directory.appendingPathComponent("custom.theme")
    try "theme[main_fg]=\"#123456\"".write(to: source, atomically: true, encoding: .utf8)
    let imported = try store.importTheme(from: source).resolvingSymlinksInPath()
    XCTAssertTrue(try store.availableThemes().contains(BtopTheme(title: "custom", value: "custom.theme")))
    XCTAssertTrue(try store.availableThemes().contains(BtopTheme(title: "custom (Imported)", value: imported.path)))
    let applied = expectation(description: "Selected theme applied")
    let controller = SettingsWindowController(
      preferences: AppPreferences(defaults: MemoryDefaults()), onChange: { _ in },
      onLayoutInteractionEnded: {}, onLayoutInteractionBegan: {}, onAppearancePreview: { _ in },
      onAppearancePreviewEnded: {}, onCornerRadiusPreview: {}, onDesktopIconsChanged: { _ in false },
      onThemeSelected: { value in
        XCTAssertEqual(value, imported.path)
        try configuration.setTheme(value)
        applied.fulfill()
      }, themeStore: store)
    let form = try XCTUnwrap(controller.window?.contentView as? SettingsView)
    form.layoutSubtreeIfNeeded()
    let scroll = try XCTUnwrap(form.subviews.first as? NSScrollView)
    let document = try XCTUnwrap(scroll.documentView)
    let stack = try XCTUnwrap(document.subviews.first as? NSStackView)
    let card = try XCTUnwrap(stack.views.dropFirst().first as? SettingsCard)
    XCTAssertTrue(form.controls.theme.isDescendant(of: card))
    XCTAssertGreaterThan(document.frame.height, scroll.contentView.bounds.height)
    let item = try XCTUnwrap(form.controls.theme.itemArray.first {
      ($0.representedObject as? String) == imported.path
    })
    form.controls.theme.select(item)
    form.selectTheme()
    XCTAssertFalse(form.controls.theme.isEnabled)
    await fulfillment(of: [applied], timeout: 2)
    try await Task.sleep(for: .milliseconds(20))
    XCTAssertTrue(form.controls.theme.isEnabled)
    form.restoreDefaults()
    XCTAssertEqual(try store.selectedTheme(), imported.path)
    XCTAssertEqual(form.controls.theme.selectedItem?.representedObject as? String, imported.path)
  }
}

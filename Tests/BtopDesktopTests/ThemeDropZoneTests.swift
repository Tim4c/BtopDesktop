import AppKit
import XCTest
@testable import BtopDesktop

final class ThemeDropZoneTests: XCTestCase {
  @MainActor func testOnlyOneRegularThemeFileIsAccepted() throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let theme = fixture.directory.appendingPathComponent("custom.theme")
    try "theme[main_fg]=\"#123456\"".write(to: theme, atomically: true, encoding: .utf8)
    let zone = ThemeDropZone(target: nil, action: nil)
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.writeObjects([theme as NSURL])
    XCTAssertEqual(zone.themeURL(from: pasteboard), theme)
    pasteboard.clearContents()
    pasteboard.writeObjects([theme as NSURL, fixture.directory.appendingPathComponent("btop") as NSURL])
    XCTAssertNil(zone.themeURL(from: pasteboard))
    pasteboard.clearContents()
    pasteboard.writeObjects([fixture.directory.appendingPathComponent("btop") as NSURL])
    XCTAssertNil(zone.themeURL(from: pasteboard))
    pasteboard.clearContents()
    let directory = fixture.directory.appendingPathComponent("folder.theme")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    pasteboard.writeObjects([directory as NSURL])
    XCTAssertNil(zone.themeURL(from: pasteboard))
  }

  @MainActor func testClickKeepsFilePickerEvent() throws {
    let form = SettingsView()
    var requested = false
    form.onEvent = { event in
      if case .importTheme = event { requested = true }
    }
    form.importTheme()
    XCTAssertTrue(requested)
  }
}

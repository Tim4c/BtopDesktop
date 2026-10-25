import Foundation
import XCTest
@testable import BtopDesktop

final class BtopConfigurationStoreTests: XCTestCase {
  func testMigrationPreservesOptionsAndImportsWithoutOverwritingTheNewConfiguration() throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let root = fixture.directory.appendingPathComponent("BtopDesktop")
    let themes = root.appendingPathComponent("btop/themes")
    try FileManager.default.createDirectory(at: themes, withIntermediateDirectories: true)
    let theme = themes.appendingPathComponent("custom.theme")
    try "theme[main_fg]=\"#123456\"".write(to: theme, atomically: true, encoding: .utf8)
    let legacy = root.appendingPathComponent("btop.conf")
    let content = "proc_tree = true\nsave_config_on_exit = false\ncolor_theme = \"\(theme.path)\"\n"
    try content.write(to: legacy, atomically: true, encoding: .utf8)
    let store = BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory))
    let migrated = try store.configurationURL(prepareForLaunch: false)
    XCTAssertEqual(migrated, root.appendingPathComponent("btop/btop.conf"))
    XCTAssertEqual(try String(contentsOf: migrated, encoding: .utf8), content)
    XCTAssertEqual(try String(contentsOf: legacy, encoding: .utf8), content)
    XCTAssertEqual(try BtopThemeStore(configurationStore: store).selectedTheme(), theme.path)
    XCTAssertTrue(try BtopThemeStore(configurationStore: store).availableThemes().contains { $0.value == theme.path })
    try "new settings\n".write(to: migrated, atomically: true, encoding: .utf8)
    _ = try store.configurationURL(prepareForLaunch: false)
    XCTAssertEqual(try String(contentsOf: migrated, encoding: .utf8), "new settings\n")
  }

  func testFirstLaunchCopiesStandaloneConfigurationWithoutModifyingIt() throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let legacy = fixture.directory.appendingPathComponent(".config/btop/btop.conf")
    try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "proc_tree = true\n".write(to: legacy, atomically: true, encoding: .utf8)
    let store = BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory))
    let configuration = try store.configurationURL(prepareForLaunch: false)
    XCTAssertEqual(try String(contentsOf: configuration, encoding: .utf8), "proc_tree = true\n")
    XCTAssertEqual(try String(contentsOf: legacy, encoding: .utf8), "proc_tree = true\n")
  }
}

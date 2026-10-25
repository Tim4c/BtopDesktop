import Foundation
import XCTest
@testable import BtopDesktop

final class BtopThemeStoreTests: XCTestCase {
  func testImportCopiesThemeAndRequiresExplicitReplacement() throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let configuration = BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory))
    let store = BtopThemeStore(configurationStore: configuration)
    let source = fixture.directory.appendingPathComponent("custom.theme")
    try "theme[main_fg]=\"#123456\"\n".write(to: source, atomically: true, encoding: .utf8)
    let destination = try store.importTheme(from: source)
    let expected = fixture.directory.appendingPathComponent("BtopDesktop/btop/themes/btopdesktop-imported-custom.theme")
    XCTAssertEqual(destination.path, expected.path)
    try "theme[main_fg]=\"255 128 0\"\n".write(to: source, atomically: true, encoding: .utf8)
    XCTAssertThrowsError(try store.importTheme(from: source))
    XCTAssertTrue(try String(contentsOf: destination, encoding: .utf8).contains("#123456"))
    _ = try store.importTheme(from: source, replacingExisting: true)
    XCTAssertThrowsError(try store.importTheme(from: destination))
    try FileManager.default.removeItem(at: source)
    XCTAssertTrue(try String(contentsOf: destination, encoding: .utf8).contains("255 128 0"))
  }

  func testUnusableThemeNamesAreRejectedBeforeImport() throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let store = BtopThemeStore(configurationStore:
      BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory)))
    for name in ["quoted\"name", "line\nbreak", "carriage\rreturn"] {
      let source = fixture.directory.appendingPathComponent(name + ".theme")
      try "theme[main_fg]=\"#123456\"\n".write(to: source, atomically: true, encoding: .utf8)
      XCTAssertThrowsError(try store.importTheme(from: source))
      let destination = fixture.directory.appendingPathComponent(
        "BtopDesktop/btop/themes/btopdesktop-imported-" + name + ".theme")
      XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }
  }

  func testInvalidThemesAreRejectedBeforeCreatingFiles() throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let store = BtopThemeStore(configurationStore:
      BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory)))
    let source = fixture.directory.appendingPathComponent("invalid.theme")
    for content in ["# comment only", "unrelated text", "theme[main_fg]=\"#12345Z\"",
                    "theme[main_fg]=\"999 0 0\"", "theme[main_fg]=\"\""] {
      try content.write(to: source, atomically: true, encoding: .utf8)
      XCTAssertThrowsError(try store.importTheme(from: source))
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath:
      fixture.directory.appendingPathComponent("BtopDesktop/btop/themes/btopdesktop-imported-invalid.theme").path))
  }

  func testCatalogReadsDoNotRewriteOptionsAndThemeWritesPreserveOtherValues() throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let configuration = BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory))
    let file = try configuration.configurationURL()
    let original = "save_config_on_exit = false\nproc_tree = true\ncolor_theme = \"TTY\"\n"
    try original.write(to: file, atomically: true, encoding: .utf8)
    let store = BtopThemeStore(configurationStore: configuration, bundledThemes: fixture.directory)
    XCTAssertEqual(try store.selectedTheme(), "TTY")
    XCTAssertEqual(try store.availableThemes().map(\.value), ["Default", "TTY"])
    XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), original)
    try configuration.setTheme("Default")
    let saved = try String(contentsOf: file, encoding: .utf8)
    XCTAssertTrue(saved.contains("proc_tree = true"))
    XCTAssertEqual(saved.components(separatedBy: "color_theme").count, 2)
  }

  func testBundledThemeFormatsAreAccepted() throws {
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let themes = project.appendingPathComponent("Vendor/themes")
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let store = BtopThemeStore(configurationStore:
      BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory)))
    for source in try FileManager.default.contentsOfDirectory(at: themes, includingPropertiesForKeys: nil)
      where source.pathExtension == "theme" {
      XCTAssertFalse(source.lastPathComponent.hasPrefix(BtopThemeStore.importedPrefix))
      _ = try store.importTheme(from: source)
    }
  }
}

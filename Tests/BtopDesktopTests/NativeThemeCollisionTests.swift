import AppKit
import SwiftTerm
import XCTest
@testable import BtopDesktop

final class NativeThemeCollisionTests: XCTestCase {
  @MainActor func testSelectedImportAndBundledThemeWithTheSameNameRenderTheirOwnColors() async throws {
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let original = project.appendingPathComponent("BtopDesktop.app/Contents/Resources/bin/btop")
    guard FileManager.default.isExecutableFile(atPath: original.path) else { throw XCTSkip("Build the app first.") }
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let resources = fixture.directory.appendingPathComponent("Resources")
    let binary = resources.appendingPathComponent("bin/btop")
    let bundled = resources.appendingPathComponent("themes")
    try FileManager.default.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: bundled, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: original, to: binary)
    let name = "collision.theme"
    try "theme[main_fg]=\"#654321\"\n".write(
      to: bundled.appendingPathComponent(name), atomically: true, encoding: .utf8)
    let configuration = BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory))
    let source = fixture.directory.appendingPathComponent(name)
    try "theme[main_fg]=\"#123456\"\n".write(to: source, atomically: true, encoding: .utf8)
    let store = BtopThemeStore(configurationStore: configuration, bundledThemes: bundled)
    let imported = try store.importTheme(from: source).resolvingSymlinksInPath()
    let runtime = TerminalRuntime(logDirectory: fixture.directory,
      tools: TerminalRuntimeTools(btop: binary, themes: bundled),
      configurationStore: BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory)))
    try configuration.setTheme(imported.path)
    let first = try await runtime.start()
    try await verifyColor(.trueColor(red: 18, green: 52, blue: 86), endpoint: first)
    try await runtime.stopForThemeChange(name)
    let second = try await runtime.startWithTheme(name, onTermination: nil)
    try await verifyColor(.trueColor(red: 101, green: 67, blue: 33), endpoint: second)
    try await runtime.stopForThemeChange(imported.path)
    let third = try await runtime.startWithTheme(imported.path, onTermination: nil)
    try await verifyColor(.trueColor(red: 18, green: 52, blue: 86), endpoint: third)
    await runtime.stop()
    // btop's own theme menu can save only the filename; it must still select the import after restart.
    try configuration.setTheme(imported.lastPathComponent)
    let reopened = try await runtime.start()
    try await verifyColor(.trueColor(red: 18, green: 52, blue: 86), endpoint: reopened)
    await runtime.stop()
    XCTAssertEqual(try store.selectedTheme(), imported.lastPathComponent)
    XCTAssertTrue(try String(contentsOf: imported, encoding: .utf8).contains("#123456"))
    XCTAssertTrue(try String(contentsOf: bundled.appendingPathComponent(name), encoding: .utf8).contains("#654321"))
  }

  @MainActor private func verifyColor(_ color: Attribute.Color, endpoint: TerminalEndpoint) async throws {
    let controller = TerminalViewController()
    controller.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
    let ready = expectation(description: "Selected theme rendered")
    controller.onLoadStateChanged = { if controller.isReady { ready.fulfill() } }
    controller.show(endpoint: endpoint)
    await fulfillment(of: [ready], timeout: 5)
    controller.onLoadStateChanged = nil
    let terminal = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? NativeTerminalView }.first)
    let grid = terminal.getTerminal()
    func hasColor() -> Bool {
      (0..<grid.rows).contains { row in
        (0..<grid.cols).contains { column in grid.getCharData(col: column, row: row)?.attribute.fg == color }
      }
    }
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !hasColor() && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertTrue(hasColor(), "The selected file must supply the rendered colors, even when filenames collide.")
  }
}

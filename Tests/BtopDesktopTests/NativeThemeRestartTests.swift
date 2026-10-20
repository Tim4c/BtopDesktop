import AppKit
import SwiftTerm
import XCTest
@testable import BtopDesktop

final class NativeThemeRestartTests: XCTestCase {
  @MainActor func testRealBtopSavesUnsavedOptionsBeforeApplyingThemeInSamePanel() async throws {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let resources = project.appendingPathComponent("BtopDesktop.app/Contents/Resources")
    let binary = resources.appendingPathComponent("bin/btop")
    guard FileManager.default.isExecutableFile(atPath: binary.path) else { throw XCTSkip("Build the app first.") }
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let configuration = try BtopConfigurationStore(fileManager:
      NativeTestFileManager(root: fixture.directory)).configurationURL()
    try "proc_tree = false\ncolor_theme = \"Default\"\n".write(to: configuration, atomically: true, encoding: .utf8)
    let runtime = TerminalRuntime(logDirectory: fixture.directory,
      tools: TerminalRuntimeTools(btop: binary, themes: resources.appendingPathComponent("themes")),
      configurationStore: BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory)))
    let window = DesktopWindowController(preferences: AppPreferences(defaults: MemoryDefaults()))
    let controller = try XCTUnwrap(Mirror(reflecting: window).children
      .first { $0.label == "terminalController" }?.value as? TerminalViewController)
    let panel = try XCTUnwrap(Mirror(reflecting: window).children
      .first { $0.label == "panel" }?.value as? DesktopPanel)
    defer { panel.orderOut(nil) }
    let first = try await runtime.start()
    try await show(window, controller: controller, endpoint: first)
    await runtime.send(Data("e".utf8))
    try await Task.sleep(for: .milliseconds(300))
    XCTAssertTrue(try String(contentsOf: configuration, encoding: .utf8).contains("proc_tree = false"))
    window.previewTheme()
    try await runtime.stopForThemeChange("TTY")
    XCTAssertTrue(first.output.exitedSuccessfully)
    XCTAssertTrue(try String(contentsOf: configuration, encoding: .utf8).contains("proc_tree = true"))
    let second = try await runtime.startWithTheme("TTY", onTermination: nil)
    try await show(window, controller: controller, endpoint: second)
    XCTAssertTrue(panel === controller.view.window)
    XCTAssertFalse(panel.hasExplicitClickFocus)
    let terminal = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? NativeTerminalView }.first)
    XCTAssertTrue(terminal.layer?.filters?.isEmpty == true)
    window.endAppearancePreview()
    XCTAssertFalse(terminal.layer?.filters?.isEmpty ?? true)
    let saved = try String(contentsOf: configuration, encoding: .utf8)
    XCTAssertTrue(saved.contains("proc_tree = true"))
    XCTAssertTrue(saved.contains("color_theme = \"TTY\""))
    await runtime.stop()
  }

  @MainActor private func show(
    _ window: DesktopWindowController, controller: TerminalViewController, endpoint: TerminalEndpoint
  ) async throws {
    let ready = expectation(description: "Terminal revealed")
    let original = controller.onLoadStateChanged
    controller.onLoadStateChanged = {
      original?()
      if controller.isReady { ready.fulfill() }
    }
    window.show(endpoint: endpoint)
    await fulfillment(of: [ready], timeout: 5)
    controller.onLoadStateChanged = original
  }
}

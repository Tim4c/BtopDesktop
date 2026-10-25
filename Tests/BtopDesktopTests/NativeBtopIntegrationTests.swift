import AppKit
import CoreImage
import SwiftTerm
import XCTest
@testable import BtopDesktop

final class NativeBtopIntegrationTests: XCTestCase {
  @MainActor func testRealBtopWithSharedSettingsPanelAndAppearance() async throws {
    try await verifyRealBtop(terminalSync: false)
  }

  @MainActor func testRealBtopWithSynchronizedOutput() async throws {
    try await verifyRealBtop(terminalSync: true)
  }

  @MainActor private func verifyRealBtop(terminalSync: Bool) async throws {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let resources = project.appendingPathComponent("BtopDesktop.app/Contents/Resources")
    let binary = resources.appendingPathComponent("bin/btop")
    guard FileManager.default.isExecutableFile(atPath: binary.path) else {
      throw XCTSkip("Build the native app before running its real-btop integration check.")
    }
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let configurationStore = BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory))
    let configuration = try configurationStore.configurationURL()
    let theme = terminalSync ? "integration-custom" : "tokyo-night"
    if terminalSync { try importIntegrationTheme(into: configurationStore, directory: fixture.directory) }
    try "terminal_sync = \(terminalSync)\ncolor_theme = \"\(theme)\"\nlog_level = \"DEBUG\"\n"
      .write(to: configuration, atomically: true, encoding: .utf8)
    let runtime = TerminalRuntime(
      logDirectory: fixture.directory,
      tools: TerminalRuntimeTools(btop: binary, themes: resources.appendingPathComponent("themes")),
      configurationStore: BtopConfigurationStore(fileManager: NativeTestFileManager(root: fixture.directory)))
    let preferences = makePreferences()
    let window = DesktopWindowController(preferences: preferences)
    let panel: DesktopPanel = try field("panel", in: window)
    defer { panel.orderOut(nil) }
    let controller: TerminalViewController = try field("terminalController", in: window)
    let ready = expectation(description: "Real btop rendered")
    let originalCallback = controller.onLoadStateChanged
    controller.onLoadStateChanged = {
      originalCallback?()
      if controller.isReady { ready.fulfill() }
    }
    let endpoint = try await runtime.start()
    window.show(endpoint: endpoint)
    window.setMode(.wallpaper)
    await fulfillment(of: [ready], timeout: 8)
    controller.onLoadStateChanged = originalCallback
    let terminal = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? NativeTerminalView }.first)
    try await Task.sleep(for: .milliseconds(300))
    try await verifyInteraction(window: window, panel: panel, terminal: terminal,
                                controller: controller, resources: resources)
    try await verifySettings(window: window, preferences: preferences, panel: panel, terminal: terminal)
    await runtime.stop()
    XCTAssertGreaterThan(try Data(contentsOf: configuration).count, 500)
    let savedConfiguration = try String(contentsOf: configuration, encoding: .utf8)
    XCTAssertTrue(savedConfiguration.contains("terminal_sync = \(terminalSync)"))
    XCTAssertFalse(terminal.getTerminal().synchronizedOutputActive)
    // btop 1.4.8 does not initialize its logger when launched with -c.
    XCTAssertTrue(savedConfiguration.contains("color_theme = \"\(theme)\""))
  }

  private func importIntegrationTheme(into store: BtopConfigurationStore, directory: URL) throws {
    let source = directory.appendingPathComponent("integration-custom.theme")
    try "theme[main_fg]=\"#123456\"\n".write(to: source, atomically: true, encoding: .utf8)
    _ = try BtopThemeStore(configurationStore: store).importTheme(from: source)
  }

  @MainActor private func makePreferences() -> AppPreferences {
    let preferences = AppPreferences(defaults: MemoryDefaults())
    preferences.inactiveOpacity = 0.3
    preferences.activeOpacity = 0.8
    preferences.inactiveGrayscaleEnabled = true
    preferences.activeGrayscaleEnabled = false
    preferences.inactiveBorderEnabled = false
    preferences.activeBorderEnabled = false
    return preferences
  }

  @MainActor private func verifyInteraction(
    window: DesktopWindowController, panel: DesktopPanel,
    terminal: NativeTerminalView, controller: TerminalViewController, resources: URL
  ) async throws {
    XCTAssertTrue(screen(terminal).contains("cpu"))
    XCTAssertTrue(panel.ignoresMouseEvents)
    XCTAssertFalse(panel.canBecomeKey)
    XCTAssertEqual(terminal.alphaValue, 0.3, accuracy: 0.01)
    XCTAssertFalse(terminal.layer?.filters?.isEmpty ?? true)
    window.setMode(.interactive)
    XCTAssertFalse(panel.ignoresMouseEvents)
    XCTAssertFalse(panel.canBecomeKey)
    let click = try XCTUnwrap(NSEvent.mouseEvent(
      with: .leftMouseDown, location: NSPoint(x: 100, y: panel.frame.height - 100),
      modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil,
      eventNumber: 0, clickCount: 1, pressure: 1))
    panel.sendEvent(click)
    XCTAssertTrue(panel.hasExplicitClickFocus)
    XCTAssertTrue(panel.canBecomeKey)
    // Input and terminal redraw are checked against the real program, not a fixture.
    let manifest = try String(contentsOf: resources.appendingPathComponent("licenses/vendor-manifest.tsv"),
                              encoding: .utf8)
    let entry = try XCTUnwrap(manifest.split(separator: "\n").first { $0.hasPrefix("btop\t") })
    let version = try XCTUnwrap(entry.split(separator: "\t").dropFirst().first)
    controller.send(source: terminal, data: Array("m".utf8)[...])
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while !screen(terminal).contains("v\(version)") && clock.now < deadline {
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertTrue(screen(terminal).contains("v\(version)"))
    controller.send(source: terminal, data: [27][...])
  }

  @MainActor private func verifySettings(
    window: DesktopWindowController, preferences: AppPreferences,
    panel: DesktopPanel, terminal: NativeTerminalView
  ) async throws {
    let settings = makeSettings(preferences: preferences, window: window)
    let form = try XCTUnwrap(settings.window?.contentView as? SettingsView)
    form.controls.activeOpacity.doubleValue = 0.6
    form.valueChanged(form.controls.activeOpacity)
    try await Task.sleep(for: .milliseconds(300))
    XCTAssertEqual(terminal.alphaValue, 0.6, accuracy: 0.01)
    XCTAssertTrue(terminal.layer?.filters?.isEmpty == true)
    form.controls.cornerRadius.doubleValue = 18
    form.valueChanged(form.controls.cornerRadius)
    XCTAssertEqual(panel.contentView?.layer?.cornerRadius, 18)
    settings.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    try await Task.sleep(for: .milliseconds(300))
    XCTAssertFalse(panel.canBecomeKey)
    XCTAssertFalse(panel.hasExplicitClickFocus)
    XCTAssertEqual(terminal.alphaValue, 0.3, accuracy: 0.01)
    XCTAssertFalse(terminal.layer?.filters?.isEmpty ?? true)
    XCTAssertEqual(panel.contentView?.layer?.borderWidth, 0)
    preferences.panelWidthRatio = 0.6
    window.applyPreferences(layoutChanged: true, manualLayoutChange: false)
    XCTAssertEqual(panel.contentView?.layer?.borderWidth, 0)
    try await Task.sleep(for: .milliseconds(300))
    XCTAssertTrue(screen(terminal).contains("cpu"))
  }

  @MainActor private func makeSettings(
    preferences: AppPreferences, window: DesktopWindowController
  ) -> SettingsWindowController {
    SettingsWindowController(
      preferences: preferences,
      onChange: { window.applyPreferences(layoutChanged: $0) },
      onLayoutInteractionEnded: { window.finishTerminalResize() },
      onLayoutInteractionBegan: { window.beginLayoutInteraction() },
      onAppearancePreview: { window.previewAppearance(active: $0) },
      onAppearancePreviewEnded: { window.endAppearancePreview() },
      onCornerRadiusPreview: { window.previewCornerRadius() },
      onDesktopIconsChanged: { _ in false },
      onSettingsClosed: { window.deactivateInteraction() })
  }

  @MainActor private func field<Value>(_ name: String, in object: Any) throws -> Value {
    try XCTUnwrap(Mirror(reflecting: object).children.first { $0.label == name }?.value as? Value)
  }

  @MainActor private func screen(_ terminal: TerminalView) -> String {
    let grid = terminal.getTerminal()
    return (0..<grid.rows).compactMap { grid.getLine(row: $0)?.translateToString(endCol: grid.cols) }
      .joined(separator: "\n")
  }
}

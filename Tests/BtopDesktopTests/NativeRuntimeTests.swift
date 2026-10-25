import Foundation
import XCTest
@testable import BtopDesktop

final class NativeRuntimeTests: XCTestCase {
  func testGracefulStopSavesConfigurationAndCoalescesRequests() async throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let received = expectation(description: "PTY output")
    let endpoint = try await fixture.runtime.start()
    endpoint.output.attach { data in
      if String(data: data, encoding: .utf8)?.contains("cpu fixture") == true { received.fulfill() }
    }
    await fulfillment(of: [received], timeout: 5)
    async let first: Void = fixture.runtime.stop()
    async let second: Void = fixture.runtime.stop()
    _ = await (first, second)
    let saved = fixture.directory.appendingPathComponent("BtopDesktop/btop/btop.conf")
    XCTAssertEqual(try String(contentsOf: saved, encoding: .utf8), "saved_on_sigint = true\n")
    XCTAssertTrue(endpoint.output.hasTerminated)
  }

  func testInvalidCatalogThemeDoesNotStopRunningProcess() async throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let theme = "quoted\"name.theme"
    try "theme[main_fg]=\"#123456\"".write(
      to: fixture.directory.appendingPathComponent(theme), atomically: true, encoding: .utf8)
    let ready = expectation(description: "Ready")
    let endpoint = try await fixture.runtime.start()
    endpoint.output.attach { _ in ready.fulfill() }
    await fulfillment(of: [ready], timeout: 5)
    do {
      try await fixture.runtime.stopForThemeChange(theme)
      XCTFail("An unusable theme must be rejected before stopping btop")
    } catch BtopThemeImportError.invalidTheme {}
    XCTAssertFalse(endpoint.output.hasTerminated)
    await fixture.runtime.stop()
  }

  func testNaturalQuitCallsTerminationHandler() async throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let output = expectation(description: "Ready")
    let exited = expectation(description: "Natural exit")
    let endpoint = try await fixture.runtime.start { exited.fulfill() }
    endpoint.output.attach { _ in output.fulfill() }
    await fulfillment(of: [output], timeout: 5)
    await fixture.runtime.send(Data("q".utf8))
    await fulfillment(of: [exited], timeout: 5)
    await fixture.runtime.stop()
  }

  func testThemeRestartWritesOnlyAfterSavingAndShutdownPreventsRestart() async throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let output = expectation(description: "Ready")
    let endpoint = try await fixture.runtime.start()
    endpoint.output.attach { _ in output.fulfill() }
    await fulfillment(of: [output], timeout: 5)
    await fixture.runtime.stop()
    let restarted = try await fixture.runtime.startWithTheme("Default", onTermination: nil)
    XCTAssertTrue(endpoint.output.exitedSuccessfully)
    XCTAssertFalse(restarted.output.hasTerminated)
    let configuration = fixture.directory.appendingPathComponent("BtopDesktop/btop/btop.conf")
    let saved = try String(contentsOf: configuration, encoding: .utf8)
    XCTAssertTrue(saved.contains("saved_on_sigint = true"))
    XCTAssertTrue(saved.contains("color_theme = \"Default\""))
    await fixture.runtime.shutdown()
    do {
      _ = try await fixture.runtime.start()
      XCTFail("Shutdown must prevent another process from starting")
    } catch TerminalRuntimeError.alreadyRunning {}
  }

  func testThemeChangeDoesNotStopBtopWhenSavingIsDisabled() async throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let ready = expectation(description: "Ready")
    let endpoint = try await fixture.runtime.start()
    endpoint.output.attach { _ in ready.fulfill() }
    await fulfillment(of: [ready], timeout: 5)
    let configuration = fixture.directory.appendingPathComponent("BtopDesktop/btop/btop.conf")
    try "save_config_on_exit = false\n".write(to: configuration, atomically: true, encoding: .utf8)
    do {
      try await fixture.runtime.stopForThemeChange("Default")
      XCTFail("Unsaved options must not be discarded")
    } catch TerminalRuntimeError.configurationSavingDisabled {}
    XCTAssertFalse(endpoint.output.hasTerminated)
    XCTAssertEqual(try String(contentsOf: configuration, encoding: .utf8), "save_config_on_exit = false\n")
    let recovered = try await fixture.runtime.recoverAfterThemeChange(onTermination: nil)
    XCTAssertNil(recovered)
    await fixture.runtime.stop()
  }

  @MainActor func testUnresponsiveProcessStopsWithoutBlockingUI() async throws {
    let fixture = try NativeFixture(ignoreInterrupt: true)
    defer { fixture.cleanup() }
    let output = expectation(description: "Ready")
    let endpoint = try await fixture.runtime.start()
    endpoint.output.attach { _ in output.fulfill() }
    await fulfillment(of: [output], timeout: 5)
    var heartbeat = 0
    let ticks = Task { @MainActor in
      for _ in 0..<10 {
        try await Task.sleep(for: .milliseconds(20))
        heartbeat += 1
      }
    }
    let clock = ContinuousClock()
    let began = clock.now
    await fixture.runtime.stop()
    try await ticks.value
    XCTAssertEqual(heartbeat, 10)
    XCTAssertTrue(endpoint.output.hasTerminated)
    XCTAssertLessThan(began.duration(to: clock.now), .seconds(5))
    do {
      _ = try await fixture.runtime.startWithTheme("Default", onTermination: nil)
      XCTFail("A forced stop must not apply a theme")
    } catch TerminalRuntimeError.unsafeThemeChange {}
    let configuration = fixture.directory.appendingPathComponent("BtopDesktop/btop/btop.conf")
    XCTAssertFalse(try String(contentsOf: configuration, encoding: .utf8).contains("color_theme"))
  }
}

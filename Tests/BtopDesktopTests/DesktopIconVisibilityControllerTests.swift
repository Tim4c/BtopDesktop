import Foundation
import XCTest
@testable import BtopDesktop

private final class FinderCommands: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: Bool?
  private var calls: [[String]] = []
  var failRestart = false
  var failRestore = false

  init(hidden: Bool?) { stored = hidden }
  var hidden: Bool? { lock.withLock { stored } }
  var operations: [String] { lock.withLock { calls.compactMap(\.first) } }

  func execute(_ executable: String, _ arguments: [String]) throws -> DesktopCommandResult {
    lock.withLock {
      calls.append(arguments)
      if executable == "/usr/bin/killall" {
        return DesktopCommandResult(status: failRestart ? 1 : 0, output: "")
      }
      if arguments.first == "read" {
        return DesktopCommandResult(status: stored == nil ? 1 : 0, output: stored == true ? "0" : "1")
      }
      if failRestore && calls.count > 3 { return DesktopCommandResult(status: 2, output: "") }
      stored = arguments.first == "delete" ? nil : arguments.last == "false"
      return DesktopCommandResult(status: 0, output: "")
    }
  }
}

final class DesktopIconVisibilityControllerTests: XCTestCase {
  func testRestartFailureRestoresExistingAndAbsentPreferences() async throws {
    for previous: Bool? in [false, true, nil] {
      let commands = FinderCommands(hidden: previous)
      commands.failRestart = true
      let controller = DesktopIconVisibilityController(execute: commands.execute)
      do {
        try await controller.setDesktopIconsHidden(!(previous ?? false))
        XCTFail("Restart failure must be reported")
      } catch DesktopIconVisibilityError.commandFailed {}
      XCTAssertEqual(commands.hidden, previous)
      XCTAssertEqual(commands.operations, ["read", "write", "Finder", previous == nil ? "delete" : "write"])
    }
  }

  @MainActor func testSlowCommandLeavesMainActorResponsive() async throws {
    let started = expectation(description: "Finder command started")
    let release = DispatchSemaphore(value: 0)
    let commands = FinderCommands(hidden: false)
    let controller = DesktopIconVisibilityController { executable, arguments in
      XCTAssertFalse(Thread.isMainThread)
      if executable == "/usr/bin/killall" {
        started.fulfill()
        XCTAssertEqual(release.wait(timeout: .now() + 2), .success,
                       "The main actor must be able to release a blocked command")
      }
      return try commands.execute(executable, arguments)
    }
    let change = Task { try await controller.setDesktopIconsHidden(true) }
    await fulfillment(of: [started], timeout: 3)
    var heartbeat = 0
    for _ in 0..<3 {
      try await Task.sleep(for: .milliseconds(10))
      heartbeat += 1
    }
    release.signal()
    try await change.value
    XCTAssertEqual(heartbeat, 3)
    XCTAssertEqual(commands.hidden, true)
  }

  func testSuccessfulChangeKeepsRequestedPreference() async throws {
    let commands = FinderCommands(hidden: false)
    let controller = DesktopIconVisibilityController(execute: commands.execute)
    try await controller.setDesktopIconsHidden(true)
    XCTAssertEqual(commands.hidden, true)
    XCTAssertEqual(commands.operations, ["read", "write", "Finder"])
  }

  func testRollbackFailureIsReported() async throws {
    let commands = FinderCommands(hidden: false)
    commands.failRestart = true
    commands.failRestore = true
    let controller = DesktopIconVisibilityController(execute: commands.execute)
    do {
      try await controller.setDesktopIconsHidden(true)
      XCTFail("Rollback failure must be reported")
    } catch DesktopIconVisibilityError.rollbackFailed {}
  }
}

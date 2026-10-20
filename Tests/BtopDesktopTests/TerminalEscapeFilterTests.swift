import AppKit
import XCTest
@testable import BtopDesktop

final class TerminalEscapeFilterTests: XCTestCase {
  @MainActor func testFirstEscapeAfterFocusGainIsConsumedWithoutWarmup() throws {
    let target = EscapeTestResponder()
    var focused = false
    let filter = TerminalEscapeFilter { focused ? target : nil }
    let press = try event(keyCode: 53, down: true)
    let release = try event(keyCode: 53, down: false)
    XCTAssertFalse(filter.handle(type: .keyDown, event: press))
    XCTAssertFalse(filter.handle(type: .keyUp, event: release))
    XCTAssertEqual(target.presses, 0)
    focused = true
    XCTAssertTrue(filter.handle(type: .keyDown, event: press))
    XCTAssertTrue(filter.handle(type: .keyUp, event: release))
    XCTAssertEqual(target.presses, 1)
    XCTAssertEqual(target.releases, 1)
  }

  @MainActor func testEscapeDeliveredOnceAndReleaseConsumedAfterFocusLoss() throws {
    let target = EscapeTestResponder()
    var focused = true
    let filter = TerminalEscapeFilter { focused ? target : nil }
    let press = try event(keyCode: 53, down: true)
    XCTAssertTrue(filter.handle(type: .keyDown, event: press))
    XCTAssertEqual(target.presses, 1)
    press.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
    XCTAssertTrue(filter.handle(type: .keyDown, event: press))
    XCTAssertEqual(target.presses, 2)
    focused = false
    XCTAssertTrue(filter.handle(type: .keyUp, event: try event(keyCode: 53, down: false)))
    XCTAssertEqual(target.releases, 0)
    XCTAssertFalse(filter.handle(type: .keyDown, event: press))
  }

  @MainActor func testFocusedEscapePairAndOtherShortcuts() throws {
    let target = EscapeTestResponder()
    let filter = TerminalEscapeFilter { target }
    XCTAssertFalse(filter.handle(type: .keyUp, event: try event(keyCode: 53, down: false)))
    for modifier: CGEventFlags in [.maskCommand, .maskControl, .maskAlternate, .maskShift] {
      let modified = try event(keyCode: 53, down: true)
      modified.flags = modifier
      XCTAssertFalse(filter.handle(type: .keyDown, event: modified))
    }
    XCTAssertFalse(filter.handle(type: .keyDown, event: try event(keyCode: 0, down: true)))
    XCTAssertTrue(filter.handle(type: .keyDown, event: try event(keyCode: 53, down: true)))
    XCTAssertTrue(filter.handle(type: .keyUp, event: try event(keyCode: 53, down: false)))
    XCTAssertEqual(target.presses, 1)
    XCTAssertEqual(target.releases, 1)
  }

  @MainActor func testEscapeReachesNativeTerminalAndClosesMenu() async throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let controller = TerminalViewController()
    controller.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
    controller.show(endpoint: try await fixture.runtime.start())
    let terminal = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? NativeTerminalView }.first)
    try await Task.sleep(for: .milliseconds(300))
    controller.send(source: terminal, data: Array("m".utf8)[...])
    try await Task.sleep(for: .milliseconds(200))
    XCTAssertTrue(text(terminal).contains("OPTIONS"))
    let filter = TerminalEscapeFilter { terminal }
    XCTAssertTrue(filter.handle(type: .keyDown, event: try event(keyCode: 53, down: true)))
    XCTAssertTrue(filter.handle(type: .keyUp, event: try event(keyCode: 53, down: false)))
    try await Task.sleep(for: .milliseconds(200))
    XCTAssertFalse(text(terminal).contains("OPTIONS"))
    XCTAssertTrue(text(terminal).contains("cpu fixture"))
    await fixture.runtime.stop()
  }

  private func event(keyCode: CGKeyCode, down: Bool) throws -> CGEvent {
    let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down))
    event.flags = []
    return event
  }

  @MainActor private func text(_ terminal: NativeTerminalView) -> String {
    let grid = terminal.getTerminal()
    return (0..<grid.rows).compactMap { grid.getLine(row: $0)?.translateToString(endCol: grid.cols) }
      .joined(separator: "\n")
  }
}

@MainActor
private final class EscapeTestResponder: NSResponder {
  var presses = 0
  var releases = 0
  override func keyDown(with event: NSEvent) { presses += 1 }
  override func keyUp(with event: NSEvent) { releases += 1 }
}

import AppKit
import CoreImage
import SwiftTerm
import XCTest
@testable import BtopDesktop

final class NativeTerminalTests: XCTestCase {
  @MainActor func testRenderingAppearanceKeyboardAndResize() async throws {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let endpoint = try await fixture.runtime.start()
    let controller = TerminalViewController()
    controller.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
    let ready = expectation(description: "Native view ready")
    controller.onLoadStateChanged = { if controller.isReady { ready.fulfill() } }
    controller.show(endpoint: endpoint)
    await fulfillment(of: [ready], timeout: 5)
    controller.onLoadStateChanged = nil
    let terminal = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? NativeTerminalView }.first)
    XCTAssertTrue(text(terminal).contains("cpu fixture"))
    XCTAssertEqual(terminal.font.pointSize, 12)
    XCTAssertEqual(terminal.backgroundOpacity, 0)
    controller.setGrayscale(true)
    let filter = try XCTUnwrap(terminal.layer?.filters?.first as? CIFilter)
    XCTAssertEqual(filter.name, "CIColorMatrix")
    let image = CIImage(color: CIColor(red: 1, green: 0, blue: 0, alpha: 1))
    filter.setValue(image, forKey: kCIInputImageKey)
    let context = CIContext(options: [.workingColorSpace: NSNull()])
    var pixel = [Float](repeating: 0, count: 4)
    try pixel.withUnsafeMutableBytes { bytes in
      context.render(try XCTUnwrap(filter.outputImage), toBitmap: bytes.baseAddress!, rowBytes: 16,
                     bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
    }
    XCTAssertEqual(pixel[0], 0.2126, accuracy: 0.001)
    XCTAssertEqual(pixel[1], pixel[0], accuracy: 0.001)
    XCTAssertEqual(pixel[2], pixel[0], accuracy: 0.001)
    filter.setValue(nil, forKey: kCIInputImageKey)
    controller.setOpacity(0.4)
    try await Task.sleep(for: .milliseconds(300))
    XCTAssertEqual(terminal.alphaValue, 0.4, accuracy: 0.01)
    controller.setGrayscale(false)
    XCTAssertTrue(terminal.layer?.filters?.isEmpty == true)
    controller.send(source: terminal, data: Array("m".utf8)[...])
    try await Task.sleep(for: .milliseconds(200))
    XCTAssertTrue(text(terminal).contains("OPTIONS"))
    controller.view.frame.size = NSSize(width: 700, height: 400)
    controller.synchronizeSize()
    try await Task.sleep(for: .milliseconds(200))
    let grid = terminal.getTerminal()
    XCTAssertTrue(text(terminal).contains("\(grid.cols)x\(grid.rows)"))
    controller.setFontSize(18)
    try await Task.sleep(for: .milliseconds(200))
    XCTAssertEqual(terminal.font.pointSize, 18)
    XCTAssertTrue(text(terminal).contains("\(grid.cols)x\(grid.rows)"))
    await fixture.runtime.stop()
  }

  @MainActor func testWholeCellGridStaysCenteredAtDifferentPanelSizes() throws {
    let controller = TerminalViewController()
    controller.loadViewIfNeeded()
    let terminal = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? NativeTerminalView }.first)
    for size in [NSSize(width: 903, height: 607), NSSize(width: 700, height: 400),
                 NSSize(width: 1217, height: 713)] {
      controller.view.frame.size = size
      controller.view.layoutSubtreeIfNeeded()
      XCTAssertEqual(terminal.frame.midX, controller.view.bounds.midX, accuracy: 0.001)
      XCTAssertEqual(terminal.frame.midY, controller.view.bounds.midY, accuracy: 0.001)
      let optimal = terminal.getOptimalFrameSize().size
      XCTAssertEqual(terminal.bounds.width, optimal.width, accuracy: 0.001)
      XCTAssertEqual(terminal.bounds.height, optimal.height, accuracy: 0.001)
      XCTAssertGreaterThanOrEqual(terminal.frame.minX, 4 - 0.001)
      XCTAssertGreaterThanOrEqual(terminal.frame.minY, 4 - 0.001)
    }
  }

  @MainActor func testFontSizeRecalculatesCenteredGrid() throws {
    let controller = TerminalViewController()
    controller.view.frame = NSRect(x: 0, y: 0, width: 903, height: 607)
    controller.view.layoutSubtreeIfNeeded()
    let terminal = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? NativeTerminalView }.first)
    let initialColumns = terminal.getTerminal().cols
    for size: CGFloat in [18, 20, 10, 12] {
      controller.setFontSize(size)
      XCTAssertEqual(terminal.font.pointSize, size)
      XCTAssertEqual(terminal.frame.midX, controller.view.bounds.midX, accuracy: 0.001)
      XCTAssertEqual(terminal.frame.midY, controller.view.bounds.midY, accuracy: 0.001)
      XCTAssertEqual(terminal.bounds.width, terminal.getOptimalFrameSize().width, accuracy: 0.001)
      if size > 12 { XCTAssertLessThan(terminal.getTerminal().cols, initialColumns) }
    }
  }

  @MainActor func testStaleRevealCannotMarkReplacementReady() async throws {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let first = try NativeFixture()
    let second = try NativeFixture()
    defer { first.cleanup(); second.cleanup() }
    let controller = TerminalViewController()
    let initial = try await first.runtime.start()
    controller.show(endpoint: initial)
    try await Task.sleep(for: .milliseconds(100))
    let replacement = TerminalEndpoint(runtime: second.runtime, output: NativeProcessBridge(onTermination: nil))
    controller.show(endpoint: replacement)
    try await Task.sleep(for: .milliseconds(400))
    XCTAssertFalse(controller.isReady)
    let splash = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? SplashView }.first)
    XCTAssertFalse(splash.isHidden)
    await first.runtime.stop()
  }

  @MainActor func testRevealWaitsForSynchronizedFrameToFinish() async throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let output = NativeProcessBridge(onTermination: nil)
    let controller = TerminalViewController()
    controller.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
    controller.show(endpoint: TerminalEndpoint(runtime: fixture.runtime, output: output))
    output.dataReceived(slice: Array("\u{1b}[?2026h\u{1b}[2J\u{1b}[Hpartial".utf8)[...])
    try await Task.sleep(for: .milliseconds(400))
    XCTAssertFalse(controller.isReady)
    output.dataReceived(slice: Array(" complete\u{1b}[?2026l".utf8)[...])
    try await Task.sleep(for: .milliseconds(150))
    XCTAssertTrue(controller.isReady)
  }

  @MainActor func testRevealIgnoresInitializationAndWaitsForQuietOutput() async throws {
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let output = NativeProcessBridge(onTermination: nil)
    var now = Date(timeIntervalSince1970: 0)
    let controller = TerminalViewController(now: { now })
    controller.view.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
    controller.show(endpoint: TerminalEndpoint(runtime: fixture.runtime, output: output))
    output.dataReceived(slice: Array("\u{1b}[2J\u{1b}[H".utf8)[...])
    try await Task.sleep(for: .milliseconds(150))
    XCTAssertFalse(controller.isReady)
    let terminal = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? NativeTerminalView }.first)
    for index in 1...5 {
      output.dataReceived(slice: Array("content ".utf8)[...])
      let deadline = ContinuousClock.now.advanced(by: .seconds(2))
      while !text(terminal).contains(String(repeating: "content ", count: index))
              && ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(5))
      }
      XCTAssertTrue(text(terminal).contains(String(repeating: "content ", count: index)))
      now.addTimeInterval(0.03)
      XCTAssertFalse(controller.isReady)
    }
    let ready = expectation(description: "Terminal revealed after quiet output")
    controller.onLoadStateChanged = { if controller.isReady { ready.fulfill() } }
    now.addTimeInterval(0.049)
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertFalse(controller.isReady)
    now.addTimeInterval(0.002)
    await fulfillment(of: [ready], timeout: 2)
    controller.onLoadStateChanged = nil
    XCTAssertTrue(controller.isReady)
  }

  @MainActor private func text(_ terminal: TerminalView) -> String {
    let grid = terminal.getTerminal()
    return (0..<grid.rows).compactMap { grid.getLine(row: $0)?.translateToString(endCol: grid.cols) }
      .joined(separator: "\n")
  }
}

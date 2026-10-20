import AppKit
import CoreImage
import XCTest
@testable import BtopDesktop

final class OverviewBlurRenderingTests: XCTestCase {
  @MainActor func testConfirmedStatesApplyAndRemoveFixedBlurImmediately() throws {
    let controller = TerminalViewController()
    let terminal = try terminalView(in: controller)
    for state: DesktopOverviewState in [.missionControl, .appExpose, .desktop,
                                        .appExpose, .showDesktop, .missionControl, .desktop] {
      controller.setOverviewState(state)
      let filters = terminal.layer?.filters as? [CIFilter] ?? []
      XCTAssertEqual(filters.map(\.name), state.isOverview ? ["overviewBlur"] : [])
      if state.isOverview {
        XCTAssertEqual(filters.first?.value(forKey: kCIInputRadiusKey) as? CGFloat, 3)
      }
      XCTAssertTrue(terminal.layer?.animationKeys()?.isEmpty ?? true)
    }
  }

  @MainActor func testHiddenTerminalAppliesBlurWithoutAFrameClock() throws {
    let controller = TerminalViewController()
    let terminal = try terminalView(in: controller)
    terminal.isHidden = true
    controller.setOverviewState(.missionControl)
    let radius = terminal.layer?.value(forKeyPath: "filters.overviewBlur.inputRadius") as? CGFloat
    XCTAssertEqual(try XCTUnwrap(radius), 3)
    controller.setOverviewState(.showDesktop)
    XCTAssertTrue(terminal.layer?.filters?.isEmpty ?? true)
  }

  @MainActor func testOverviewPreservesGrayscaleOnExit() throws {
    let controller = TerminalViewController()
    let terminal = try terminalView(in: controller)
    controller.setGrayscale(true)
    controller.setOverviewState(.missionControl)
    let filters = try XCTUnwrap(terminal.layer?.filters as? [CIFilter])
    XCTAssertEqual(filters.map(\.name), ["CIColorMatrix", "overviewBlur"])
    controller.setOverviewState(.desktop)
    XCTAssertEqual((terminal.layer?.filters as? [CIFilter])?.map(\.name), ["CIColorMatrix"])
  }

  @MainActor func testOverviewStateBeforeViewLoadAndEndpointReplacement() async throws {
    let controller = TerminalViewController()
    controller.setOverviewState(.appExpose)
    let terminal = try terminalView(in: controller)
    let fixture = try NativeFixture()
    defer { fixture.cleanup() }
    let endpoint = try await fixture.runtime.start()
    controller.show(endpoint: endpoint)
    XCTAssertEqual(terminal.layer?.value(forKeyPath: "filters.overviewBlur.inputRadius") as? CGFloat, 3)
    controller.setOverviewState(.desktop)
    XCTAssertTrue(terminal.layer?.filters?.isEmpty ?? true)
    await fixture.runtime.stop()
  }

  @MainActor private func terminalView(in controller: TerminalViewController) throws -> NativeTerminalView {
    controller.loadViewIfNeeded()
    return try XCTUnwrap(controller.view.subviews.compactMap { $0 as? NativeTerminalView }.first)
  }
}

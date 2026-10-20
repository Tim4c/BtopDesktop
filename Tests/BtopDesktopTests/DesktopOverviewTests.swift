import XCTest
@testable import BtopDesktop

final class DesktopOverviewTests: XCTestCase {
  func testDetectedModesAndShowDesktopPrecedence() {
    XCTAssertEqual(DesktopOverviewState.detected(in: []), .desktop)
    XCTAssertEqual(DesktopOverviewState.detected(in: ["launchpad"]), .desktop)
    XCTAssertEqual(DesktopOverviewState.detected(in: ["mc"]), .missionControl)
    XCTAssertEqual(DesktopOverviewState.detected(in: ["appexpose"]), .appExpose)
    XCTAssertEqual(DesktopOverviewState.detected(in: ["mc", "showdesktop"]), .showDesktop)
    XCTAssertEqual(DesktopOverviewState.detected(in: ["showdesktop", "appexpose"]), .showDesktop)
  }

  func testOnlyMissionControlAndExposeAreOverviewStates() {
    XCTAssertTrue(DesktopOverviewState.missionControl.isOverview)
    XCTAssertTrue(DesktopOverviewState.appExpose.isOverview)
    XCTAssertFalse(DesktopOverviewState.desktop.isOverview)
    XCTAssertFalse(DesktopOverviewState.showDesktop.isOverview)
  }
}

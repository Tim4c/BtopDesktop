import Foundation

enum DesktopOverviewState: Equatable, Sendable {
  case desktop
  case showDesktop
  case missionControl
  case appExpose

  var isOverview: Bool { self == .missionControl || self == .appExpose }

  static func detected(in identifiers: [String]) -> Self {
    if identifiers.contains("showdesktop") { return .showDesktop }
    if identifiers.contains("mc") { return .missionControl }
    if identifiers.contains("appexpose") { return .appExpose }
    return .desktop
  }
}

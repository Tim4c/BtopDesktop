import Foundation

struct PanelPreferences: Equatable {
  var activeGrayscaleEnabled: Bool = false
  var inactiveGrayscaleEnabled: Bool = true
  var activeOpacity: CGFloat = 1
  var inactiveOpacity: CGFloat = 0.75
  var panelWidthRatio: CGFloat = 0.75
  var panelHeightRatio: CGFloat = 0.55
  var panelHorizontalAnchor: Int = 1
  var panelVerticalAnchor: Int = 1
  var activeBorderColor: String = "89B4FA"
  var inactiveBorderColor: String = "535763"
  var panelCornerRadius: CGFloat = 10
  var activeBorderEnabled: Bool = true
  var inactiveBorderEnabled: Bool = false
  var dimensionsLinked: Bool = false
  var fontSize: CGFloat = 12
}

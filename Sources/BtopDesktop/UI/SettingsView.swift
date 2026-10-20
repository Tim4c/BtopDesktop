import AppKit

enum SettingsChange {
  case fontSize
  case layout
  case position
  case activeAppearance
  case inactiveAppearance
  case cornerRadius
  case dimensionsLink
}

enum SettingsEvent {
  case changed(PanelPreferences, SettingsChange)
  case desktopIcons(Bool)
  case selectedTheme(String)
  case importTheme
  case droppedTheme(URL)
  case restoreDefaults
}

@MainActor
final class SettingsView: NSVisualEffectView {
  let controls = SettingsFormControls()
  var onEvent: ((SettingsEvent) -> Void)?
  private var panelSettings = PanelPreferences()
  private var linkedAspectRatio = 1.0

  init() {
    super.init(frame: .zero)
    buildInterface()
  }

  required init?(coder: NSCoder) { nil }

  func configureTracking(
    began: @escaping () -> Void, ended: @escaping () -> Void,
    cornerEnded: @escaping () -> Void
  ) {
    controls.width.onTrackingBegan = began
    controls.height.onTrackingBegan = began
    controls.width.onTrackingEnded = ended
    controls.height.onTrackingEnded = ended
    controls.cornerRadius.onTrackingEnded = cornerEnded
  }

  func display(panel: PanelPreferences, desktopIconsHidden: Bool) {
    panelSettings = panel
    controls.activeGrayscale.state = panel.activeGrayscaleEnabled ? .on : .off
    controls.inactiveGrayscale.state = panel.inactiveGrayscaleEnabled ? .on : .off
    controls.activeOpacity.doubleValue = panel.activeOpacity
    controls.inactiveOpacity.doubleValue = panel.inactiveOpacity
    controls.width.doubleValue = panel.panelWidthRatio * 100
    controls.height.doubleValue = panel.panelHeightRatio * 100
    controls.cornerRadius.doubleValue = panel.panelCornerRadius
    controls.fontSize.doubleValue = panel.fontSize
    controls.activeBorderEnabled.state = panel.activeBorderEnabled ? .on : .off
    controls.inactiveBorderEnabled.state = panel.inactiveBorderEnabled ? .on : .off
    controls.activeBorderColor.color = color(from: panel.activeBorderColor)
    controls.inactiveBorderColor.color = color(from: panel.inactiveBorderColor)
    setDesktopIconsHidden(desktopIconsHidden)
    linkedAspectRatio = controls.height.doubleValue / controls.width.doubleValue
    updateDimensionsLinkButton()
    updateValueLabels()
    updatePositionGrid()
    updateModeHeaders(previewingActive: nil)
  }

  func setDesktopIconsHidden(_ hidden: Bool) {
    controls.hideDesktopIcons.state = hidden ? .on : .off
  }

  func showPreview(active: Bool?) {
    updateModeHeaders(previewingActive: active)
  }

  @objc func selectTheme() {
    guard let value = controls.theme.selectedItem?.representedObject as? String else { return }
    onEvent?(.selectedTheme(value))
  }

  @objc func importTheme() { onEvent?(.importTheme) }

  @objc func restoreDefaults() { onEvent?(.restoreDefaults) }

  @objc func selectPosition(_ sender: NSButton) {
    panelSettings.panelHorizontalAnchor = sender.tag % 3
    panelSettings.panelVerticalAnchor = 2 - sender.tag / 3
    updatePositionGrid()
    onEvent?(.changed(panelSettings, .position))
  }

  @objc func toggleDimensionsLink() {
    panelSettings.dimensionsLinked.toggle()
    if panelSettings.dimensionsLinked {
      linkedAspectRatio = controls.height.doubleValue / controls.width.doubleValue
    }
    updateDimensionsLinkButton()
    onEvent?(.changed(panelSettings, .dimensionsLink))
  }

  @objc func valueChanged(_ sender: Any?) {
    if sender as AnyObject? === controls.hideDesktopIcons {
      onEvent?(.desktopIcons(controls.hideDesktopIcons.state == .on))
      return
    }
    if sender as AnyObject? === controls.fontSize {
      controls.fontSize.doubleValue = controls.fontSize.doubleValue.rounded()
      panelSettings.fontSize = CGFloat(controls.fontSize.doubleValue)
      updateValueLabels()
      onEvent?(.changed(panelSettings, .fontSize))
      return
    }
    if panelSettings.dimensionsLinked, sender as AnyObject? === controls.width {
      controls.height.doubleValue = min(100, max(30, controls.width.doubleValue * linkedAspectRatio))
    } else if panelSettings.dimensionsLinked, sender as AnyObject? === controls.height {
      controls.width.doubleValue = min(100, max(30, controls.height.doubleValue / linkedAspectRatio))
    }
    readControls()
    updateValueLabels()
    let change: SettingsChange
    if sender as AnyObject? === controls.width || sender as AnyObject? === controls.height {
      change = .layout
    } else if sender as AnyObject? === controls.activeGrayscale || sender as AnyObject? === controls.activeOpacity
      || sender as AnyObject? === controls.activeBorderColor
      || sender as AnyObject? === controls.activeBorderEnabled {
      change = .activeAppearance
    } else if sender as AnyObject? === controls.inactiveGrayscale || sender as AnyObject? === controls.inactiveOpacity
      || sender as AnyObject? === controls.inactiveBorderColor
      || sender as AnyObject? === controls.inactiveBorderEnabled {
      change = .inactiveAppearance
    } else {
      change = .cornerRadius
    }
    onEvent?(.changed(panelSettings, change))
  }

  private func readControls() {
    panelSettings.activeGrayscaleEnabled = controls.activeGrayscale.state == .on
    panelSettings.inactiveGrayscaleEnabled = controls.inactiveGrayscale.state == .on
    panelSettings.activeOpacity = CGFloat(controls.activeOpacity.doubleValue)
    panelSettings.inactiveOpacity = CGFloat(controls.inactiveOpacity.doubleValue)
    panelSettings.panelWidthRatio = CGFloat(controls.width.doubleValue / 100)
    panelSettings.panelHeightRatio = CGFloat(controls.height.doubleValue / 100)
    panelSettings.panelCornerRadius = CGFloat(controls.cornerRadius.doubleValue)
    panelSettings.activeBorderEnabled = controls.activeBorderEnabled.state == .on
    panelSettings.inactiveBorderEnabled = controls.inactiveBorderEnabled.state == .on
    panelSettings.activeBorderColor = hex(from: controls.activeBorderColor.color)
    panelSettings.inactiveBorderColor = hex(from: controls.inactiveBorderColor.color)
  }
}

extension SettingsView {
  private func updateModeHeaders(previewingActive: Bool?) {
    let activeIsPreviewed = previewingActive == true
    let inactiveIsPreviewed = previewingActive == false
    controls.activeModeTitle.stringValue = activeIsPreviewed ? "ACTIVE MODE  •  PREVIEW" : "ACTIVE MODE"
    controls.inactiveModeTitle.stringValue =
      inactiveIsPreviewed ? "INACTIVE MODE  •  PREVIEW" : "INACTIVE MODE"
    controls.activeModeTitle.textColor = activeIsPreviewed ? .controlAccentColor : .secondaryLabelColor
    controls.inactiveModeTitle.textColor = inactiveIsPreviewed ? .controlAccentColor : .secondaryLabelColor
  }

  private func updatePositionGrid() {
    let selectedTag = (2 - panelSettings.panelVerticalAnchor) * 3 + panelSettings.panelHorizontalAnchor
    for button in controls.positionButtons {
      let selected = button.tag == selectedTag
      button.layer?.backgroundColor =
        (selected ? NSColor.controlAccentColor.withAlphaComponent(0.22) : .clear).cgColor
      button.layer?.borderWidth = selected ? 1 : 0
      button.layer?.borderColor = NSColor.controlAccentColor.cgColor
      button.image = NSImage(
        systemSymbolName: selected ? "circle.inset.filled" : "circle", accessibilityDescription: nil
      )
      button.contentTintColor = selected ? .controlAccentColor : .tertiaryLabelColor
    }
  }

  private func updateValueLabels() {
    for (slider, multiplier, suffix) in [
      (controls.activeOpacity, 100.0, "%"), (controls.inactiveOpacity, 100.0, "%"), (controls.width, 1.0, "%"),
      (controls.height, 1.0, "%"), (controls.cornerRadius, 1.0, " pt"), (controls.fontSize, 1.0, " pt")
    ] {
      guard let row = slider.superview as? NSStackView, let value = row.views.last as? NSTextField
      else { continue }
      value.stringValue = "\(Int((slider.doubleValue * multiplier).rounded()))\(suffix)"
    }
  }

  private func updateDimensionsLinkButton() {
    let isLinked = panelSettings.dimensionsLinked
    controls.dimensionsLinkButton.image = NSImage(
      systemSymbolName: isLinked ? "link" : "link.badge.plus", accessibilityDescription: nil)
    controls.dimensionsLinkButton.toolTip = isLinked ? "Unlock dimensions" : "Link width and height"
    controls.dimensionsLinkButton.contentTintColor = isLinked ? .controlAccentColor : .secondaryLabelColor
    controls.dimensionsLinkButton.layer?.backgroundColor =
      (isLinked
      ? NSColor.controlAccentColor.withAlphaComponent(0.18)
      : NSColor.controlBackgroundColor.withAlphaComponent(0.72)).cgColor
    controls.dimensionsLinkButton.layer?.borderWidth = 1
    controls.dimensionsLinkButton.layer?.borderColor =
      (isLinked ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
  }
  private func color(from hex: String) -> NSColor {
    let value = UInt64(hex, radix: 16) ?? 0
    return NSColor(
      srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255, alpha: 1)
  }

  private func hex(from color: NSColor) -> String {
    let rgb = color.usingColorSpace(.sRGB) ?? color
    return String(
      format: "%02X%02X%02X", Int((rgb.redComponent * 255).rounded()),
      Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
  }
}

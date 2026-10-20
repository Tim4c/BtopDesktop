import AppKit

extension SettingsView {
  func displayThemes(_ themes: [BtopTheme], selected: String) {
    controls.theme.removeAllItems()
    for theme in themes {
      controls.theme.addItem(withTitle: theme.title)
      controls.theme.lastItem?.representedObject = theme.value
    }
    let selectedValue = selected.hasPrefix("/")
      ? URL(fileURLWithPath: selected).resolvingSymlinksInPath().path : selected
    let legacyName = URL(fileURLWithPath: selected).lastPathComponent
    let match = themes.firstIndex { $0.value == selectedValue }
      ?? themes.firstIndex { URL(fileURLWithPath: $0.value).lastPathComponent == legacyName
        || URL(fileURLWithPath: $0.value).deletingPathExtension().lastPathComponent == selected }
    controls.theme.selectItem(at: match ?? 0)
  }

  func makeThemeCard() -> NSView {
    controls.theme.target = self
    controls.theme.action = #selector(selectTheme)
    controls.theme.setAccessibilityLabel("Select theme")
    let label = NSTextField(labelWithString: "Select")
    label.font = .systemFont(ofSize: 13, weight: .medium)
    label.widthAnchor.constraint(equalToConstant: 100).isActive = true
    let row = NSStackView(views: [label, controls.theme])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 10
    row.widthAnchor.constraint(equalToConstant: 412).isActive = true
    let zone = ThemeDropZone(target: self, action: #selector(importTheme))
    zone.onDrop = { [weak self] source in self?.onEvent?(.droppedTheme(source)) }
    return SettingsCard(title: "Theme", icon: "paintpalette", rows: [row, zone])
  }
}

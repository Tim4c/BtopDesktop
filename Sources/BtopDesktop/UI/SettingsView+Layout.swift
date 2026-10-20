import AppKit

// Settings interface assembly.
extension SettingsView {
  func buildInterface() {
    let background = self
    configureBackground()

    let restore = makeRestoreButton()

    let stack = NSStackView(
      views: [makeHeader(resetButton: restore)] + makeSections())
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false
    let scroll = NSScrollView()
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    scroll.translatesAutoresizingMaskIntoConstraints = false
    let document = SettingsDocumentView()
    document.translatesAutoresizingMaskIntoConstraints = false
    document.addSubview(stack)
    scroll.documentView = document
    background.addSubview(scroll)
    NSLayoutConstraint.activate([
      scroll.leadingAnchor.constraint(equalTo: background.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: background.trailingAnchor),
      scroll.topAnchor.constraint(equalTo: background.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: background.bottomAnchor),
      document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
      stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 28),
      stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -28),
      stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 50),
      stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
    ])

    let interactiveControls: [NSControl] = [
      controls.activeGrayscale, controls.inactiveGrayscale, controls.activeOpacity, controls.inactiveOpacity,
      controls.width, controls.height, controls.fontSize,
      controls.cornerRadius, controls.activeBorderColor, controls.inactiveBorderColor, controls.activeBorderEnabled,
      controls.inactiveBorderEnabled, controls.hideDesktopIcons
    ]
    for control in interactiveControls {
      control.target = self
      control.action = #selector(valueChanged(_:))
    }
    controls.fontSize.numberOfTickMarks = 11
    controls.fontSize.allowsTickMarkValuesOnly = true
    controls.fontSize.setAccessibilityLabel("Font size")
    controls.dimensionsLinkButton.target = self
    controls.dimensionsLinkButton.action = #selector(toggleDimensionsLink)
    controls.dimensionsLinkButton.isBordered = false
    controls.dimensionsLinkButton.wantsLayer = true
    controls.dimensionsLinkButton.layer?.cornerRadius = 6
    controls.dimensionsLinkButton.widthAnchor.constraint(equalToConstant: 26).isActive = true
    controls.dimensionsLinkButton.heightAnchor.constraint(equalToConstant: 26).isActive = true
  }

  private func configureBackground() {
    material = .underWindowBackground
    blendingMode = .behindWindow
    state = .active
  }

  private func makeSections() -> [NSView] {
    let appearance = makeCard(
      title: "Appearance", icon: "circle.lefthalf.filled",
      rows: [
        modeHeader(controls.activeModeTitle, title: "Active mode"),
        sliderRow(title: "Opacity", slider: controls.activeOpacity, multiplier: 100),
        toggleRow(title: "Grayscale", control: controls.activeGrayscale),
        toggleRow(title: "Border", control: controls.activeBorderEnabled),
        colorRow(title: "Border color", colorWell: controls.activeBorderColor),
        divider(),
        modeHeader(controls.inactiveModeTitle, title: "Inactive mode"),
        sliderRow(title: "Opacity", slider: controls.inactiveOpacity, multiplier: 100),
        toggleRow(title: "Grayscale", control: controls.inactiveGrayscale),
        toggleRow(title: "Border", control: controls.inactiveBorderEnabled),
        colorRow(title: "Border color", colorWell: controls.inactiveBorderColor)
      ])
    let panel = makeCard(
      title: "Panel", icon: "rectangle.inset.filled",
      rows: [
        sliderRow(title: "Font size", slider: controls.fontSize, multiplier: 1, suffix: " pt"),
        divider(),
        dimensionsControls(),
        divider(),
        sliderRow(title: "Border radius", slider: controls.cornerRadius, multiplier: 1, suffix: " pt")
      ])
    let position = makeCard(
      title: "Position", icon: "rectangle.3.group",
      rows: [
        positionGrid()
      ])
    let desktop = makeCard(
      title: "Desktop", icon: "desktopcomputer",
      rows: [
        toggleRow(title: "Hide desktop icons", control: controls.hideDesktopIcons)
      ])
    return [makeThemeCard(), appearance, panel, position, desktop]
  }

  private func makeRestoreButton() -> NSView {
    let restoreButton = NSButton(
      image: NSImage(
        systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "Restore defaults")!,
      target: self, action: #selector(restoreDefaults))
    restoreButton.isBordered = false
    restoreButton.imagePosition = .imageOnly
    restoreButton.imageScaling = .scaleProportionallyDown
    restoreButton.image?.isTemplate = true
    restoreButton.contentTintColor = .controlAccentColor
    restoreButton.toolTip = "Restore defaults"

    let restore = NSVisualEffectView()
    restore.material = .contentBackground
    restore.blendingMode = .withinWindow
    restore.state = .active
    restore.wantsLayer = true
    restore.layer?.cornerRadius = 6
    restore.layer?.masksToBounds = true
    restore.translatesAutoresizingMaskIntoConstraints = false
    restore.addSubview(restoreButton)
    restoreButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      restoreButton.leadingAnchor.constraint(equalTo: restore.leadingAnchor),
      restoreButton.trailingAnchor.constraint(equalTo: restore.trailingAnchor),
      restoreButton.topAnchor.constraint(equalTo: restore.topAnchor),
      restoreButton.bottomAnchor.constraint(equalTo: restore.bottomAnchor),
      restore.widthAnchor.constraint(equalToConstant: 28),
      restore.heightAnchor.constraint(equalToConstant: 28)
    ])
    return restore
  }
}

// Settings controls and layout.
extension SettingsView {
  private func makeHeader(resetButton: NSView) -> NSView {
    let headerIcon = (NSImage(named: "MenuIcon")?.copy() as? NSImage) ?? NSImage(
      systemSymbolName: "chart.xyaxis.line", accessibilityDescription: "Btop Desktop")!
    headerIcon.size = NSSize(width: 28, height: 28)
    headerIcon.isTemplate = true
    let image = NSImageView(image: headerIcon)
    image.contentTintColor = .controlAccentColor
    let title = NSTextField(labelWithString: "Btop Desktop")
    title.font = .systemFont(ofSize: 22, weight: .bold)
    let subtitle = secondaryLabel("Customize your desktop system monitor")
    let labels = NSStackView(views: [title, subtitle])
    labels.orientation = .vertical
    labels.alignment = .leading
    labels.spacing = 2
    let spacer = NSView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    let header = NSStackView(views: [image, labels, spacer, resetButton])
    header.orientation = .horizontal
    header.alignment = .centerY
    header.spacing = 12
    return header
  }

  private func makeCard(title: String, icon: String, rows: [NSView])
    -> NSView {
    SettingsCard(title: title, icon: icon, rows: rows)
  }

  private func modeHeader(_ label: NSTextField, title: String) -> NSTextField {
    label.stringValue = title.uppercased()
    label.font = .systemFont(ofSize: 11, weight: .semibold)
    label.textColor = .secondaryLabelColor
    return label
  }

  private func secondaryLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 11)
    label.textColor = .secondaryLabelColor
    return label
  }

  private func toggleRow(title: String, control: NSSwitch) -> NSView {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .medium)
    let row = NSStackView(views: [label, control])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.distribution = .fill
    control.setContentHuggingPriority(.required, for: .horizontal)
    row.widthAnchor.constraint(equalToConstant: 412).isActive = true
    return row
  }

  private func sliderRow(
    title: String,
    slider: NSSlider,
    multiplier: Double,
    suffix: String = "%",
    rowWidth: CGFloat = 412,
    sliderMinimumWidth: CGFloat = 195
  ) -> NSView {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .medium)
    label.widthAnchor.constraint(equalToConstant: 100).isActive = true
    let value = NSTextField(labelWithString: "")
    value.alignment = .right
    value.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    value.textColor = .secondaryLabelColor
    value.widthAnchor.constraint(equalToConstant: 42).isActive = true
    let row = NSStackView(views: [label, slider, value])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 10
    row.widthAnchor.constraint(equalToConstant: rowWidth).isActive = true
    slider.widthAnchor.constraint(greaterThanOrEqualToConstant: sliderMinimumWidth).isActive = true
    return row
  }

  private func dimensionsControls() -> NSView {
    let rows = NSStackView(views: [
      sliderRow(
        title: "Width", slider: controls.width, multiplier: 1, rowWidth: 368, sliderMinimumWidth: 150),
      divider(width: 368),
      sliderRow(
        title: "Height", slider: controls.height, multiplier: 1, rowWidth: 368, sliderMinimumWidth: 150)
    ])
    rows.orientation = .vertical
    rows.alignment = .leading
    rows.spacing = 9

    let container = NSStackView(views: [rows, controls.dimensionsLinkButton])
    container.orientation = .horizontal
    container.alignment = .centerY
    container.spacing = 18
    container.widthAnchor.constraint(equalToConstant: 412).isActive = true
    return container
  }

  private func colorRow(title: String, colorWell: NSColorWell) -> NSView {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .medium)
    let row = NSStackView(views: [label, colorWell])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.distribution = .fill
    colorWell.colorWellStyle = .minimal
    colorWell.setContentHuggingPriority(.required, for: .horizontal)
    row.widthAnchor.constraint(equalToConstant: 412).isActive = true
    return row
  }

  private func positionGrid() -> NSView {
    let grid = NSStackView()
    grid.orientation = .vertical
    grid.alignment = .centerX
    grid.spacing = 6
    grid.widthAnchor.constraint(equalToConstant: 412).isActive = true
    for row in 0..<3 {
      let line = NSStackView()
      line.orientation = .horizontal
      line.alignment = .centerY
      line.spacing = 6
      for column in 0..<3 {
        let button = NSButton(title: "", target: self, action: #selector(selectPosition(_:)))
        button.tag = row * 3 + column
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.setAccessibilityLabel(
          ["Top", "Centre", "Bottom"][row] + " " + ["left", "centre", "right"][column])
        button.widthAnchor.constraint(equalToConstant: 46).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        controls.positionButtons.append(button)
        line.addArrangedSubview(button)
      }
      grid.addArrangedSubview(line)
    }
    return grid
  }

  private func divider(width: CGFloat = 412) -> NSView {
    let divider = NSBox()
    divider.boxType = .separator
    divider.widthAnchor.constraint(equalToConstant: width).isActive = true
    return divider
  }
}

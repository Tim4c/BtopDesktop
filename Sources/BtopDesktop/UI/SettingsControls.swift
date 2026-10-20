import AppKit

@MainActor
final class SettingsCard: NSVisualEffectView {
  init(title: String, icon: String, rows: [NSView]) {
    super.init(frame: .zero)
    material = .contentBackground
    blendingMode = .withinWindow
    state = .active
    wantsLayer = true
    layer?.cornerRadius = 12
    layer?.masksToBounds = true

    let iconView = NSImageView(
      image: NSImage(systemSymbolName: icon, accessibilityDescription: nil)!)
    iconView.symbolConfiguration = .init(pointSize: 13, weight: .semibold)
    iconView.contentTintColor = .controlAccentColor
    iconView.setContentHuggingPriority(.required, for: .horizontal)

    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    let spacer = NSView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    let heading = NSStackView(views: [iconView, label, spacer])
    heading.orientation = .horizontal
    heading.alignment = .centerY
    heading.spacing = 7
    heading.distribution = .fill
    heading.widthAnchor.constraint(equalToConstant: 412).isActive = true
    let body = NSStackView(views: rows)
    body.orientation = .vertical
    body.alignment = .leading
    body.spacing = 9
    let stack = NSStackView(views: [heading, body])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      widthAnchor.constraint(equalToConstant: 444),
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
    ])
  }

  required init?(coder: NSCoder) { nil }
}

@MainActor
final class TrackingSlider: NSSlider {
  var onTrackingBegan: (() -> Void)?
  var onTrackingEnded: (() -> Void)?
  private var isTracking = false

  override func mouseDown(with event: NSEvent) {
    isTracking = true
    onTrackingBegan?()
    // AppKit can consume mouse-up inside its synchronous tracking loop.
    // Always finish when that loop returns, even if mouseUp is not delivered here.
    defer { finishTrackingIfNeeded() }
    super.mouseDown(with: event)
  }

  override func mouseUp(with event: NSEvent) {
    super.mouseUp(with: event)
    finishTrackingIfNeeded()
  }

  override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
    let result = super.sendAction(action, to: target)
    if NSApp.currentEvent?.type == .leftMouseUp {
      finishTrackingIfNeeded()
    }
    return result
  }

  private func finishTrackingIfNeeded() {
    guard isTracking else { return }
    isTracking = false
    onTrackingEnded?()
  }
}

@MainActor
final class SettingsFormControls {
  let theme = NSPopUpButton(frame: .zero, pullsDown: false)
  let fontSize = NSSlider(value: 12, minValue: 10, maxValue: 20, target: nil, action: nil)
  let activeGrayscale = NSSwitch()
  let inactiveGrayscale = NSSwitch()
  let activeOpacity = NSSlider(
    value: 1, minValue: 0.1, maxValue: 1, target: nil, action: nil)
  let inactiveOpacity = NSSlider(
    value: 0.75, minValue: 0.1, maxValue: 1, target: nil, action: nil)
  let width = TrackingSlider(
    value: 80, minValue: 30, maxValue: 100, target: nil, action: nil)
  let height = TrackingSlider(
    value: 65, minValue: 30, maxValue: 100, target: nil, action: nil)
  let cornerRadius = TrackingSlider(
    value: 10, minValue: 0, maxValue: 30, target: nil, action: nil)
  let activeBorderColor = NSColorWell()
  let inactiveBorderColor = NSColorWell()
  let activeBorderEnabled = NSSwitch()
  let inactiveBorderEnabled = NSSwitch()
  let hideDesktopIcons = NSSwitch()
  let dimensionsLinkButton = NSButton(
    image: NSImage(systemSymbolName: "link", accessibilityDescription: "Link dimensions")!,
    target: nil, action: nil)
  let activeModeTitle = NSTextField(labelWithString: "")
  let inactiveModeTitle = NSTextField(labelWithString: "")
  var positionButtons: [NSButton] = []
}

@MainActor
final class SettingsDocumentView: NSView {
  override var isFlipped: Bool { true }
}

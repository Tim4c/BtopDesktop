import AppKit

@MainActor
final class DesktopWindowController: NSObject {
  private let preferences: AppPreferences
  private let panel: DesktopPanel
  private let terminalController = TerminalViewController()
  private lazy var overviewMonitor = DesktopOverviewMonitor { [weak self] state in
    self?.terminalController.setOverviewState(state)
  }
  private var resizeIndicatorID = 0
  private var layoutInteractionInProgress = false
  private var appearanceState = DesktopAppearanceState()
  private let resizingBorderColor = NSColor.controlAccentColor

  init(preferences: AppPreferences) {
    self.preferences = preferences
    let mouseLocation = NSEvent.mouseLocation
    let screen =
      NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })?.visibleFrame
      ?? NSScreen.main?.visibleFrame
      ?? .zero
    let size = NSSize(
      width: screen.width * preferences.panelWidthRatio,
      height: screen.height * preferences.panelHeightRatio)
    let origin = Self.panelOrigin(
      in: screen,
      panelSize: size,
      horizontalAnchor: preferences.panelHorizontalAnchor,
      verticalAnchor: preferences.panelVerticalAnchor
    )

    panel = DesktopPanel(
      contentRect: NSRect(origin: origin, size: size),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    super.init()
    configurePanel()
    configureTerminalView()
    NotificationCenter.default.addObserver(
      self, selector: #selector(screenParametersChanged),
      name: NSApplication.didChangeScreenParametersNotification, object: nil
    )
  }

  func show(endpoint: TerminalEndpoint) {
    panel.prepareEscapeHandling()
    terminalController.show(endpoint: endpoint)
    overviewMonitor.start()
    panel.orderFrontRegardless()
  }

  func setMode(_ mode: DesktopMode) {
    appearanceState.mode = mode
    appearanceState.clearTransientState()
    finishTerminalResize()
    let interactive = mode == .interactive
    panel.allowsInteraction = interactive
    panel.ignoresMouseEvents = !interactive
    let desktopIconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
    panel.level = NSWindow.Level(rawValue: desktopIconLevel + (interactive ? 1 : -1))
    panel.clearClickFocus()
    panel.orderFrontRegardless()
    applyCurrentAppearance()
  }

  func deactivateInteraction() {
    panel.clearClickFocus()
    appearanceState.preview = .none
    finishTerminalResize()
  }

  func applyPreferences(layoutChanged: Bool, manualLayoutChange: Bool = true) {
    appearanceState.preview = .none
    terminalController.setFontSize(preferences.fontSize)
    if layoutChanged {
      applyPanelFrame(showResizeIndicator: manualLayoutChange)
    }
    applyCurrentAppearance()
  }

  func previewTheme() {
    appearanceState.preview = .theme
    applyCurrentAppearance()
  }

  func previewAppearance(active: Bool) {
    appearanceState.preview = .appearance(active: active)
    applyCurrentAppearance()
  }

  func previewCornerRadius() {
    appearanceState.previewCornerRadius()
    applyCurrentAppearance()
  }

  func endAppearancePreview() {
    appearanceState.preview = .none
    applyCurrentAppearance()
  }

  private func applyCurrentAppearance() {
    // Wallpaper is always inactive; only an explicit Settings preview overrides it.
    let active = appearanceState.isActive(
      hasExplicitClickFocus: panel.hasExplicitClickFocus, isKeyWindow: panel.isKeyWindow)
    let configuredBorder = borderIsEnabled(active: active)
    let indicator = appearanceState.showsGuide(configuredBorder: configuredBorder)
    panel.contentView?.layer?.cornerRadius = preferences.panelCornerRadius
    panel.contentView?.layer?.borderWidth = (indicator || configuredBorder) ? 1 : 0
    setBorderColor(
      indicator ? resizingBorderColor
        : borderColor(from: active ? preferences.activeBorderColor : preferences.inactiveBorderColor))
    let grayscale = active ? preferences.activeGrayscaleEnabled : preferences.inactiveGrayscaleEnabled
    terminalController.setGrayscale(appearanceState.grayscaleEnabled(configured: grayscale))
    setTerminalOpacity(active ? preferences.activeOpacity : preferences.inactiveOpacity)
  }

  @objc private func screenParametersChanged() {
    applyPreferences(layoutChanged: true, manualLayoutChange: false)
  }

  private func applyPanelFrame(showResizeIndicator: Bool) {
    let currentScreen =
      NSScreen.screens.max(by: {
        let first = $0.frame.intersection(panel.frame)
        let second = $1.frame.intersection(panel.frame)
        return (first.isNull ? 0 : first.width * first.height)
          < (second.isNull ? 0 : second.width * second.height)
      }).flatMap { $0.frame.intersects(panel.frame) ? $0 : nil }
      ?? NSScreen.main
    guard let screen = currentScreen?.visibleFrame else { return }

    let size = NSSize(
      width: screen.width * preferences.panelWidthRatio,
      height: screen.height * preferences.panelHeightRatio
    )
    let frame = NSRect(
      origin: Self.panelOrigin(
        in: screen,
        panelSize: size,
        horizontalAnchor: preferences.panelHorizontalAnchor,
        verticalAnchor: preferences.panelVerticalAnchor
      ),
      size: size
    )
    let sizeChanged = panel.frame.size != frame.size
    if sizeChanged { beginTerminalResize(showIndicator: showResizeIndicator) }
    panel.setFrame(frame, display: true, animate: false)
    terminalController.synchronizeSize()
  }

  private func beginTerminalResize(showIndicator: Bool) {
    guard terminalController.isReady else { return }
    resizeIndicatorID += 1
    let indicatorID = resizeIndicatorID
    appearanceState.resize = showIndicator ? .manual : .automatic
    // Keep the terminal visible; show a guide only for manual adjustments.
    applyCurrentAppearance()
    guard !layoutInteractionInProgress else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
      guard let self, self.resizeIndicatorID == indicatorID else { return }
      self.appearanceState.resize = .idle
      self.applyCurrentAppearance()
    }
  }

  func finishTerminalResize() {
    layoutInteractionInProgress = false
    resizeIndicatorID += 1
    appearanceState.resize = .idle
    applyCurrentAppearance()
  }

  func beginLayoutInteraction() {
    layoutInteractionInProgress = true
    resizeIndicatorID += 1
  }
}

// Panel geometry and configuration.
extension DesktopWindowController {
  private static func panelOrigin(
    in availableFrame: NSRect,
    panelSize: NSSize,
    horizontalAnchor: Int,
    verticalAnchor: Int
  ) -> NSPoint {
    let horizontal = max(0, min(horizontalAnchor, 2))
    let vertical = max(0, min(verticalAnchor, 2))
    let originX: CGFloat =
      switch horizontal {
      case 0: availableFrame.minX
      case 2: availableFrame.maxX - panelSize.width
      default: availableFrame.midX - panelSize.width / 2
      }
    let originY: CGFloat =
      switch vertical {
      case 0: availableFrame.minY
      case 2: availableFrame.maxY - panelSize.height
      default: availableFrame.midY - panelSize.height / 2
      }
    return NSPoint(x: originX, y: originY)
  }

  private func configurePanel() {
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    panel.contentView?.wantsLayer = true
    panel.contentView?.layer?.cornerRadius = preferences.panelCornerRadius
    panel.contentView?.layer?.borderWidth = preferences.inactiveBorderEnabled ? 1 : 0
    panel.contentView?.layer?.masksToBounds = true

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeKey),
      name: NSWindow.didBecomeKeyNotification,
      object: panel
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidResignKey),
      name: NSWindow.didResignKeyNotification,
      object: panel
    )
  }

  private func configureTerminalView() {
    guard let contentView = panel.contentView else { return }
    terminalController.setFontSize(preferences.fontSize)
    let terminalView = terminalController.view
    terminalView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(terminalView)
    NSLayoutConstraint.activate([
      terminalView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      terminalView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      terminalView.topAnchor.constraint(equalTo: contentView.topAnchor),
      terminalView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    ])
    terminalController.onLoadStateChanged = { [weak self] in
      guard let self else { return }
      if !self.terminalController.isReady {
        self.resizeIndicatorID += 1
        self.appearanceState.resize = .idle
      }
      self.applyCurrentAppearance()
    }
  }

  @objc private func windowDidBecomeKey() {
    applyCurrentAppearance()
  }

  @objc private func windowDidResignKey() {
    applyCurrentAppearance()
  }

  private func setTerminalOpacity(_ value: CGFloat) {
    guard appearanceState.resize == .idle else { return }
    terminalController.setOpacity(value)
  }

  private func setBorderColor(_ color: NSColor) {
    panel.contentView?.layer?.borderColor = color.cgColor
  }

  private func borderIsEnabled(active: Bool) -> Bool {
    active ? preferences.activeBorderEnabled : preferences.inactiveBorderEnabled
  }

  private func borderColor(from hex: String) -> NSColor {
    let sanitized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else { return .clear }
    return NSColor(
      srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: 1
    )
  }
}

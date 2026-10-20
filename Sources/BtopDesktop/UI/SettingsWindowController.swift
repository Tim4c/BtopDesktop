import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  private let preferences: AppPreferences
  private let onSettingsClosed: () -> Void
  private let onChange: (_ layoutChanged: Bool) -> Void
  private let onLayoutInteractionEnded: () -> Void
  private let onAppearancePreview: (_ active: Bool) -> Void
  private let onAppearancePreviewEnded: () -> Void
  private let onCornerRadiusPreview: () -> Void
  private let onDesktopIconsChanged: (_ hidden: Bool) async -> Bool
  let themeStore: BtopThemeStore
  let onThemeSelected: ((String) async throws -> Void)?
  var desktopIconChangeTask: Task<Void, Never>?
  var themeChangeInProgress = false
  let settingsView = SettingsView()
  private var previewedAppearance: Bool?

  init(
    preferences: AppPreferences,
    onChange: @escaping (_ layoutChanged: Bool) -> Void,
    onLayoutInteractionEnded: @escaping () -> Void,
    onLayoutInteractionBegan: @escaping () -> Void,
    onAppearancePreview: @escaping (_ active: Bool) -> Void,
    onAppearancePreviewEnded: @escaping () -> Void,
    onCornerRadiusPreview: @escaping () -> Void,
    onDesktopIconsChanged: @escaping (_ hidden: Bool) async -> Bool,
    onThemeSelected: ((String) async throws -> Void)? = nil,
    themeStore: BtopThemeStore = BtopThemeStore(),
    onSettingsClosed: @escaping () -> Void = {}
  ) {
    self.themeStore = themeStore
    self.onThemeSelected = onThemeSelected
    self.onSettingsClosed = onSettingsClosed
    self.preferences = preferences
    self.onChange = onChange
    self.onLayoutInteractionEnded = onLayoutInteractionEnded
    self.onAppearancePreview = onAppearancePreview
    self.onAppearancePreviewEnded = onAppearancePreviewEnded
    self.onCornerRadiusPreview = onCornerRadiusPreview
    self.onDesktopIconsChanged = onDesktopIconsChanged
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 890),
      styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false
    )
    window.title = "Btop Desktop"
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.moveToActiveSpace]
    window.center()
    super.init(window: window)
    window.delegate = self
    window.contentView = settingsView
    settingsView.onEvent = { [weak self] event in self?.handle(event) }
    settingsView.configureTracking(
      began: onLayoutInteractionBegan, ended: onLayoutInteractionEnded,
      cornerEnded: { [weak self] in self?.finishCornerRadiusPreview() })
    loadPreferences()
  }

  required init?(coder: NSCoder) { nil }

  func show() {
    loadPreferences()
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }

  func windowDidResignKey(_ notification: Notification) {
    endSettingsInteraction()
  }

  func windowWillClose(_ notification: Notification) {
    endSettingsInteraction()
    onSettingsClosed()
  }

  private func endSettingsInteraction() {
    onLayoutInteractionEnded()
    clearAppearancePreview()
  }
}

extension SettingsWindowController {
  private func handle(_ event: SettingsEvent) {
    switch event {
    case .desktopIcons(let hidden):
      changeDesktopIcons(hidden)
    case .selectedTheme(let theme): changeTheme(theme)
    case .importTheme: importTheme()
    case .droppedTheme(let source): saveTheme(source)
    case .restoreDefaults:
      guard desktopIconChangeTask == nil else { return }
      preferences.restorePanelDefaults()
      if preferences.hideDesktopIcons { changeDesktopIcons(false) }
      previewedAppearance = nil
      loadPreferences()
      onChange(true)
    case .changed(let panel, let change):
      applyPanelChange(panel, change: change)
    }
  }

  private func changeDesktopIcons(_ hidden: Bool) {
    guard desktopIconChangeTask == nil else { return }
    settingsView.controls.hideDesktopIcons.isEnabled = false
    desktopIconChangeTask = Task { @MainActor [weak self] in
      guard let self else { return }
      if await self.onDesktopIconsChanged(hidden) { self.preferences.hideDesktopIcons = hidden }
      self.settingsView.setDesktopIconsHidden(self.preferences.hideDesktopIcons)
      self.settingsView.controls.hideDesktopIcons.isEnabled = true
      self.desktopIconChangeTask = nil
    }
  }

  private func applyPanelChange(_ panel: PanelPreferences, change: SettingsChange) {
    preferences.panelSettings = panel
    switch change {
    case .dimensionsLink: return
    case .fontSize: onChange(false)
    case .position: onChange(true)
    case .layout:
      onChange(true)
      clearAppearancePreview()
    case .activeAppearance, .inactiveAppearance:
      onChange(false)
      let active = change == .activeAppearance
      previewedAppearance = active
      settingsView.showPreview(active: active)
      onAppearancePreview(active)
    case .cornerRadius:
      onChange(false)
      if let previewedAppearance { onAppearancePreview(previewedAppearance) }
      onCornerRadiusPreview()
    }
  }

  private func loadPreferences() {
    settingsView.display(panel: preferences.panelSettings, desktopIconsHidden: preferences.hideDesktopIcons)
    refreshThemes()
  }

  private func clearAppearancePreview() {
    previewedAppearance = nil
    settingsView.showPreview(active: nil)
    onAppearancePreviewEnded()
  }

  private func finishCornerRadiusPreview() {
    if let previewedAppearance {
      onAppearancePreview(previewedAppearance)
    } else {
      onAppearancePreviewEnded()
    }
  }
}

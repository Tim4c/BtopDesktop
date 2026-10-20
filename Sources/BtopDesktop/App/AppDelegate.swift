import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let preferences = AppPreferences()
  private lazy var windowController = DesktopWindowController(preferences: preferences)
  private lazy var runtime = TerminalRuntime(
    logDirectory: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
  )
  private let desktopIconVisibilityController = DesktopIconVisibilityController()

  private var desktopIconChangeInProgress = false
  private var desktopIconRevision = 0
  private var terminationInProgress = false
  private var statusItem: NSStatusItem!
  private var modeItem: NSMenuItem!
  private var desktopIconsItem: NSMenuItem!
  private lazy var settingsWindowController = SettingsWindowController(
    preferences: preferences
  ) { [weak self] layoutChanged in
    self?.windowController.applyPreferences(layoutChanged: layoutChanged)
  } onLayoutInteractionEnded: { [weak self] in
    self?.windowController.finishTerminalResize()
  } onLayoutInteractionBegan: { [weak self] in
    self?.windowController.beginLayoutInteraction()
  } onAppearancePreview: { [weak self] active in
    self?.windowController.previewAppearance(active: active)
  } onAppearancePreviewEnded: { [weak self] in
    self?.windowController.endAppearancePreview()
  } onCornerRadiusPreview: { [weak self] in
    self?.windowController.previewCornerRadius()
  } onDesktopIconsChanged: { [weak self] hidden in
    await self?.setDesktopIconsHidden(hidden) ?? false
  } onThemeSelected: { [weak self] theme in
    try await self?.changeTheme(theme)
  } onSettingsClosed: { [weak self] in
    self?.windowController.deactivateInteraction()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    configureStatusItem()
    refreshMenu()
    Task { @MainActor in
      await synchronizeDesktopIconState()
      refreshMenu()
      guard !terminationInProgress else { return }
      do {
        let endpoint = try await runtime.start(onTermination: Self.terminalDidExit)
        guard !terminationInProgress else { return }
        windowController.show(endpoint: endpoint)
        windowController.setMode(preferences.interactiveMode ? .interactive : .wallpaper)
        refreshMenu()
      } catch {
        guard !terminationInProgress else { return }
        presentStartupError(error)
      }
    }
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard !terminationInProgress else { return .terminateLater }
    terminationInProgress = true
    let runtime = runtime
    // The main dispatch queue can be occupied by AppKit's nested termination loop.
    // Keep shutdown on the runtime actor and deliver the reply through the run loop.
    Task.detached {
      await runtime.shutdown()
      RunLoop.main.perform(inModes: [.common]) {
        MainActor.assumeIsolated { sender.reply(toApplicationShouldTerminate: true) }
      }
    }
    return .terminateLater
  }

  private static let terminalDidExit: @Sendable () -> Void = {
    RunLoop.main.perform(inModes: [.common]) {
      MainActor.assumeIsolated { NSApp.terminate(nil) }
    }
  }

  private func changeTheme(_ theme: String) async throws {
    guard !terminationInProgress else { return }
    windowController.deactivateInteraction()
    windowController.previewTheme()
    do {
      try await runtime.stopForThemeChange(theme)
      guard !terminationInProgress else { return }
      let endpoint = try await runtime.startWithTheme(theme, onTermination: Self.terminalDidExit)
      guard !terminationInProgress else { return }
      windowController.show(endpoint: endpoint)
    } catch {
      windowController.endAppearancePreview()
      if !terminationInProgress,
         let endpoint = try await runtime.recoverAfterThemeChange(onTermination: Self.terminalDidExit) {
        if !terminationInProgress { windowController.show(endpoint: endpoint) }
      }
      throw error
    }
  }

  private func synchronizeDesktopIconState() async {
    guard !desktopIconChangeInProgress else { return }
    let revision = desktopIconRevision
    if let hidden = await desktopIconVisibilityController.desktopIconsHidden(),
       revision == desktopIconRevision {
      preferences.hideDesktopIcons = hidden
    }
  }

  private func configureStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menuIcon = NSImage(named: "MenuIcon") ?? NSImage(
      systemSymbolName: "chart.xyaxis.line",
      accessibilityDescription: "Btop Desktop"
    )
    menuIcon?.size = NSSize(width: 18, height: 18)
    menuIcon?.isTemplate = true
    menuIcon?.accessibilityDescription = "Btop Desktop"
    statusItem.button?.image = menuIcon

    let menu = NSMenu()
    menu.delegate = self
    modeItem = NSMenuItem(
      title: "Enable interactive mode", action: #selector(toggleInteractiveMode), keyEquivalent: "i"
    )
    modeItem.target = self
    modeItem.keyEquivalentModifierMask = .command
    menu.addItem(modeItem)

    desktopIconsItem = NSMenuItem(
      title: "Hide desktop icons", action: #selector(toggleDesktopIcons), keyEquivalent: "h")
    desktopIconsItem.target = self
    desktopIconsItem.keyEquivalentModifierMask = .command
    menu.addItem(desktopIconsItem)

    let settingsItem = NSMenuItem(
      title: "Settings", action: #selector(showSettings), keyEquivalent: ",")
    settingsItem.target = self
    settingsItem.keyEquivalentModifierMask = .command
    menu.addItem(settingsItem)
    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)
    statusItem.menu = menu
  }

  private func setInteractiveMode(_ enabled: Bool) {
    preferences.interactiveMode = enabled
    windowController.setMode(preferences.interactiveMode ? .interactive : .wallpaper)
    refreshMenu()
  }

  @objc private func toggleInteractiveMode() {
    setInteractiveMode(!preferences.interactiveMode)
  }

  @objc private func toggleDesktopIcons() {
    Task { @MainActor in
      await synchronizeDesktopIconState()
      _ = await setDesktopIconsHidden(!preferences.hideDesktopIcons)
    }
  }

  @discardableResult
  private func setDesktopIconsHidden(_ hidden: Bool) async -> Bool {
    guard !desktopIconChangeInProgress else { return false }
    desktopIconChangeInProgress = true
    desktopIconRevision += 1
    refreshMenu()
    defer {
      desktopIconChangeInProgress = false
      refreshMenu()
    }
    do {
      try await desktopIconVisibilityController.setDesktopIconsHidden(hidden)
      preferences.hideDesktopIcons = hidden
      refreshMenu()
      return true
    } catch {
      if let hidden = await desktopIconVisibilityController.desktopIconsHidden() {
        preferences.hideDesktopIcons = hidden
      }
      presentDesktopIconError(error)
      return false
    }
  }

  @objc private func showSettings() {
    windowController.deactivateInteraction()
    Task { @MainActor in
      await synchronizeDesktopIconState()
      refreshMenu()
      settingsWindowController.show()
    }
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func refreshMenu() {
    modeItem.state = preferences.interactiveMode ? .on : .off
    modeItem.title = "Enable interactive mode"
    desktopIconsItem.isEnabled = !desktopIconChangeInProgress
    desktopIconsItem.state = preferences.hideDesktopIcons ? .on : .off
  }

  private func presentStartupError(_ error: Error) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Btop Desktop n’a pas pu démarrer"
    alert.informativeText = error.localizedDescription
    alert.runModal()
    NSApp.terminate(nil)
  }

  private func presentDesktopIconError(_ error: Error) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Les icônes du Bureau n’ont pas pu être mises à jour"
    alert.informativeText = error.localizedDescription
    alert.runModal()
  }
}

extension AppDelegate: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    Task { @MainActor in
      await synchronizeDesktopIconState()
      refreshMenu()
    }
  }
}

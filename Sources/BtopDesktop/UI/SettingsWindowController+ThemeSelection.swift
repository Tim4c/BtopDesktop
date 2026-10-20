import AppKit

extension SettingsWindowController {
  func refreshThemes() {
    do {
      settingsView.displayThemes(try themeStore.availableThemes(), selected: try themeStore.selectedTheme())
      settingsView.controls.theme.isEnabled = !themeChangeInProgress && onThemeSelected != nil
    } catch {
      settingsView.controls.theme.isEnabled = false
      showThemeMessage("Could not load themes", detail: error.localizedDescription)
    }
  }

  func changeTheme(_ theme: String) {
    guard !themeChangeInProgress, let onThemeSelected else { return }
    themeChangeInProgress = true
    settingsView.controls.theme.isEnabled = false
    Task { @MainActor [weak self] in
      guard let self else { return }
      defer {
        self.themeChangeInProgress = false
        self.refreshThemes()
      }
      do { try await onThemeSelected(theme) } catch {
        self.showThemeMessage("Could not apply theme", detail: error.localizedDescription)
      }
    }
  }
}

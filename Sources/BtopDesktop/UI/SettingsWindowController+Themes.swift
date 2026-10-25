import AppKit
import UniformTypeIdentifiers

extension SettingsWindowController {
  func importTheme() {
    guard let window else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [UTType(filenameExtension: "theme") ?? .plainText]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.message = "Choose a btop color theme (.theme)."
    panel.beginSheetModal(for: window) { [weak self] response in
      guard response == .OK, let source = panel.url else { return }
      self?.saveTheme(source)
    }
  }

  func saveTheme(_ source: URL, replacingExisting: Bool = false) {
    let scoped = source.startAccessingSecurityScopedResource()
    defer { if scoped { source.stopAccessingSecurityScopedResource() } }
    do {
      _ = try themeStore.importTheme(from: source, replacingExisting: replacingExisting)
      refreshThemes()
      showThemeMessage("Theme imported", detail:
        "Select the imported theme in the Theme selector to apply it.")
    } catch BtopThemeImportError.alreadyExists {
      confirmThemeReplacement(source)
    } catch {
      showThemeMessage("Could not import theme", detail: error.localizedDescription)
    }
  }

  private func confirmThemeReplacement(_ source: URL) {
    guard let window else { return }
    let alert = NSAlert()
    alert.messageText = "Replace imported theme?"
    alert.informativeText = "A theme named \(source.lastPathComponent) already exists."
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Replace")
    alert.beginSheetModal(for: window) { [weak self] response in
      if response == .alertSecondButtonReturn { self?.saveTheme(source, replacingExisting: true) }
    }
  }

  func showThemeMessage(_ title: String, detail: String) {
    guard let window else { return }
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = detail
    alert.addButton(withTitle: "OK")
    alert.beginSheetModal(for: window)
  }
}

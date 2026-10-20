import Foundation

extension BtopConfigurationStore {
  func configurationSavingEnabled() throws -> Bool {
    let configuration = try configurationURL(prepareForLaunch: false)
    let lines = try String(contentsOf: configuration, encoding: .utf8).components(separatedBy: .newlines)
    return !lines.contains { line in
      let fields = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
      return fields.count == 2 && fields[0] == "save_config_on_exit" && fields[1].lowercased() == "false"
    }
  }

  func setTheme(_ theme: String) throws {
    let configuration = try configurationURL()
    try BtopThemeStore.validateThemeValue(theme)
    let setting = "color_theme = \"\(theme)\""
    var lines = try String(contentsOf: configuration, encoding: .utf8).components(separatedBy: .newlines)
    lines.removeAll { line in
      line.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) == "color_theme"
    }
    lines.append(setting)
    try lines.joined(separator: "\n").write(to: configuration, atomically: true, encoding: .utf8)
  }
}

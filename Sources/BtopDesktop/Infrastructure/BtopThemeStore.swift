import Foundation

enum BtopThemeImportError: LocalizedError {
  case invalidTheme
  case alreadyExists

  var errorDescription: String? {
    switch self {
    case .invalidTheme: "Choose a UTF-8 .theme file containing valid btop color definitions."
    case .alreadyExists: "A theme with this name has already been imported."
    }
  }
}

struct BtopThemeStore {
  static let importedPrefix = "btopdesktop-imported-"
  let configurationStore: BtopConfigurationStore
  let bundledThemes: URL

  init(configurationStore: BtopConfigurationStore = BtopConfigurationStore(), bundledThemes: URL? = nil) {
    self.configurationStore = configurationStore
    self.bundledThemes = bundledThemes ?? TerminalRuntimeTools.bundled.themes
  }

  func importTheme(from source: URL, replacingExisting: Bool = false) throws -> URL {
    guard source.pathExtension.lowercased() == "theme" else { throw BtopThemeImportError.invalidTheme }
    let content = try String(contentsOf: source, encoding: .utf8)
    try validate(content)
    let root = try configurationStore.configurationURL(prepareForLaunch: false).deletingLastPathComponent()
    let directory = root.appendingPathComponent("themes", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let name = source.deletingPathExtension().lastPathComponent
    let filename = name.hasPrefix(Self.importedPrefix) ? name : Self.importedPrefix + name
    let destination = directory.appendingPathComponent(filename)
      .appendingPathExtension("theme")
    try Self.validateThemeValue(destination.path)
    if FileManager.default.fileExists(atPath: destination.path), !replacingExisting {
      throw BtopThemeImportError.alreadyExists
    }
    try content.write(to: destination, atomically: true, encoding: .utf8)
    return destination
  }

  static func validateThemeValue(_ theme: String) throws {
    guard !theme.contains("\""), !theme.contains("\n"), !theme.contains("\r") else {
      throw BtopThemeImportError.invalidTheme
    }
  }

  private func validate(_ content: String) throws {
    let keys = Set("""
      main_bg main_fg title hi_fg selected_bg selected_fg inactive_fg graph_text meter_bg proc_misc
      cpu_box mem_box net_box proc_box div_line temp_start temp_mid temp_end cpu_start cpu_mid cpu_end
      free_start free_mid free_end cached_start cached_mid cached_end available_start available_mid
      available_end used_start used_mid used_end download_start download_mid download_end upload_start
      upload_mid upload_end process_start process_mid process_end proc_pause_bg proc_follow_bg
      proc_banner_bg proc_banner_fg followed_bg followed_fg
      """.split(whereSeparator: { $0.isWhitespace }).map(String.init))
    let pattern = #"^theme\[([a-z_]+)\]\s*=\s*"([^"]*)"\s*(?:#.*)?$"#
    let expression = try NSRegularExpression(pattern: pattern)
    var recognized = false
    for rawLine in content.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespaces)
      if line.isEmpty || line.hasPrefix("#") { continue }
      let range = NSRange(line.startIndex..., in: line)
      guard let match = expression.firstMatch(in: line, range: range),
            let keyRange = Range(match.range(at: 1), in: line),
            let colorRange = Range(match.range(at: 2), in: line) else {
        throw BtopThemeImportError.invalidTheme
      }
      let key = String(line[keyRange])
      guard keys.contains(key) else { continue }
      guard validColor(String(line[colorRange]), key: key) else { throw BtopThemeImportError.invalidTheme }
      recognized = true
    }
    guard recognized else { throw BtopThemeImportError.invalidTheme }
  }

  private func validColor(_ color: String, key: String) -> Bool {
    if color.isEmpty { return key == "main_bg" || key.hasSuffix("_mid") || key.hasSuffix("_end") }
    if color.hasPrefix("#") {
      let digits = color.dropFirst()
      return [2, 6].contains(digits.count) && digits.allSatisfy { $0.isHexDigit }
    }
    let values = color.split(whereSeparator: { $0.isWhitespace })
    return values.count == 3 && values.allSatisfy { value in
      guard let number = Int(value) else { return false }
      return (0...255).contains(number)
    }
  }
}

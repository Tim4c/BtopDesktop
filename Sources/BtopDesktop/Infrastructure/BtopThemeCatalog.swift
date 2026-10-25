import Foundation

struct BtopTheme: Equatable, Sendable {
  let title: String
  let value: String
}

extension BtopThemeStore {
  func availableThemes() throws -> [BtopTheme] {
    let root = try configurationStore.configurationURL(prepareForLaunch: false).deletingLastPathComponent()
    let imported = root.appendingPathComponent("themes", isDirectory: true)
    var themes = [BtopTheme(title: "Default", value: "Default"), BtopTheme(title: "TTY", value: "TTY")]
    for (directory, suffix) in [(bundledThemes, ""), (imported, " (Imported)")] {
      guard FileManager.default.fileExists(atPath: directory.path) else { continue }
      let files = try FileManager.default.contentsOfDirectory(at: directory,
        includingPropertiesForKeys: [.isRegularFileKey])
      for file in files where file.pathExtension == "theme" {
        guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
        themes.append(BtopTheme(
          title: file.deletingPathExtension().lastPathComponent + suffix,
          value: suffix.isEmpty ? file.lastPathComponent : file.resolvingSymlinksInPath().path))
      }
    }
    return Array(themes.prefix(2)) + themes.dropFirst(2).sorted {
      $0.title.localizedStandardCompare($1.title) == .orderedAscending
    }
  }

  func selectedTheme() throws -> String {
    let configuration = try configurationStore.configurationURL(prepareForLaunch: false)
    let lines = try String(contentsOf: configuration, encoding: .utf8).components(separatedBy: .newlines)
    for line in lines {
      let fields = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
      if fields.count == 2, fields[0] == "color_theme" {
        return fields[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
      }
    }
    return "Default"
  }
}

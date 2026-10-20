import Foundation

enum BtopConfigurationStoreError: LocalizedError {
  case applicationSupportUnavailable

  var errorDescription: String? {
    switch self {
    case .applicationSupportUnavailable:
      "The Application Support directory is unavailable."
    }
  }
}

struct BtopConfigurationStore {
  private let fileManager: FileManager

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  func configurationURL(prepareForLaunch: Bool = true) throws -> URL {
    guard
      let applicationSupport = fileManager.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else {
      throw BtopConfigurationStoreError.applicationSupportUnavailable
    }

    let directory = applicationSupport.appendingPathComponent("BtopDesktop", isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let configuration = directory.appendingPathComponent("btop.conf", isDirectory: false)

    if !fileManager.fileExists(atPath: configuration.path(percentEncoded: false)) {
      let legacyConfiguration = fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/btop/btop.conf", isDirectory: false)
      if fileManager.fileExists(atPath: legacyConfiguration.path(percentEncoded: false)) {
        // Do not use FileManager.copyItem here: it can report a spurious
        // "item already exists" failure while Finder is observing this folder.
        // A single atomic write is enough for this one-time import.
        let legacyData = try Data(contentsOf: legacyConfiguration)
        try legacyData.write(to: configuration, options: .atomic)
      } else {
        try "# Btop Desktop configuration\n".write(
          to: configuration,
          atomically: true,
          encoding: .utf8
        )
      }
    }

    if prepareForLaunch { try enableConfigurationSaving(to: configuration) }
    return configuration
  }

  private func enableConfigurationSaving(to configuration: URL) throws {
    var lines = try String(contentsOf: configuration, encoding: .utf8)
      .components(separatedBy: .newlines)

    let setting = "save_config_on_exit = true"

    if let index = lines.firstIndex(where: {
      $0.trimmingCharacters(in: .whitespaces)
        .hasPrefix("save_config_on_exit")
    }) {
      lines[index] = setting
    } else {
      lines.append(setting)
    }

    try lines.joined(separator: "\n").write(
      to: configuration,
      atomically: true,
      encoding: .utf8
    )
  }
}

import Darwin
import Foundation

enum DesktopIconVisibilityError: LocalizedError {
  case commandFailed(command: String, status: Int32)
  case rollbackFailed(change: String, rollback: String)

  var errorDescription: String? {
    switch self {
    case .commandFailed(let command, let status):
      "\(command) failed (status \(status))."
    case .rollbackFailed(let change, let rollback):
      "\(change) Restoring the previous Finder preference also failed: \(rollback)"
    }
  }
}

struct DesktopCommandResult: Sendable {
  let status: Int32
  let output: String
}

// Commands run serially on this actor, away from AppKit’s main actor.
actor DesktopIconVisibilityController {
  typealias CommandExecutor = @Sendable (String, [String]) throws -> DesktopCommandResult
  private let execute: CommandExecutor

  init(execute: @escaping CommandExecutor = DesktopIconVisibilityController.executeCommand) {
    self.execute = execute
  }

  func desktopIconsHidden() -> Bool? {
    do { return try readPreference() ?? false } catch { return nil }
  }

  private func readPreference() throws -> Bool? {
    let result = try execute("/usr/bin/defaults", ["read", "com.apple.finder", "CreateDesktop"])
    if result.status == 1 { return nil } // Finder uses its default when the key is absent.
    guard result.status == 0 else {
      throw DesktopIconVisibilityError.commandFailed(command: "/usr/bin/defaults", status: result.status)
    }
    return result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "0"
      || result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "false"
  }

  func setDesktopIconsHidden(_ hidden: Bool) throws {
    let previous = try readPreference()
    try writePreference(hidden)
    do {
      try run(executable: "/usr/bin/killall", arguments: ["Finder"])
    } catch {
      let changeError = error
      do {
        if let previous {
          try writePreference(previous)
        } else {
          try run(executable: "/usr/bin/defaults", arguments: ["delete", "com.apple.finder", "CreateDesktop"])
        }
      } catch {
        throw DesktopIconVisibilityError.rollbackFailed(
          change: changeError.localizedDescription, rollback: error.localizedDescription)
      }
      throw changeError
    }
  }

  private func writePreference(_ hidden: Bool) throws {
    try run(executable: "/usr/bin/defaults",
            arguments: ["write", "com.apple.finder", "CreateDesktop", "-bool", hidden ? "false" : "true"])
  }

  private func run(executable: String, arguments: [String]) throws {
    let result = try execute(executable, arguments)
    guard result.status == 0 else {
      throw DesktopIconVisibilityError.commandFailed(command: executable, status: result.status)
    }
  }

  private static func executeCommand(_ executable: String, _ arguments: [String]) throws -> DesktopCommandResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    let deadline = Date().addingTimeInterval(2)
    while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
    if process.isRunning {
      Darwin.kill(process.processIdentifier, SIGKILL)
      process.waitUntilExit()
      throw DesktopIconVisibilityError.commandFailed(command: executable, status: -1)
    }
    return DesktopCommandResult(status: process.terminationStatus,
      output: String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
  }
}

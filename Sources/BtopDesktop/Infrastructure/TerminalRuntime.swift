import Darwin
import Foundation
import SwiftTerm

enum TerminalRuntimeError: LocalizedError {
  case missingBundledTool(URL)
  case alreadyRunning
  case launchFailed
  case unsafeThemeChange
  case configurationSavingDisabled

  var errorDescription: String? {
    switch self {
    case .missingBundledTool(let url): "Missing bundled runtime tool: \(url.lastPathComponent)"
    case .alreadyRunning: "The terminal runtime is already running or stopping."
    case .launchFailed: "Could not create the native btop terminal."
    case .configurationSavingDisabled:
      "Enable Save config on exit in btop before changing its theme from Settings."
    case .unsafeThemeChange:
      "btop did not stop cleanly. The theme was not changed because its settings may not be saved."
    }
  }
}

actor TerminalRuntime {
  private var process: NativePTYConnection?
  private var bridge: NativeProcessBridge?
  private var stopTask: Task<Bool, Never>?
  private var lastStopWasGraceful = false
  private var shuttingDown = false
  private let tools: TerminalRuntimeTools
  private let configurationStore: BtopConfigurationStore
  private let logURL: URL

  init(logDirectory: URL, tools: TerminalRuntimeTools = .bundled,
       configurationStore: sending BtopConfigurationStore = BtopConfigurationStore()) {
    self.tools = tools
    self.configurationStore = configurationStore
    logURL = logDirectory.appendingPathComponent("BtopDesktop/native-terminal.log")
  }

  func start(onTermination: (@Sendable () -> Void)? = nil) throws -> TerminalEndpoint {
    guard !shuttingDown, process == nil, stopTask == nil else { throw TerminalRuntimeError.alreadyRunning }
    guard FileManager.default.isExecutableFile(atPath: tools.btop.path) else {
      throw TerminalRuntimeError.missingBundledTool(tools.btop)
    }
    let configuration = try configurationStore.configurationURL()
    let output = NativeProcessBridge(onTermination: onTermination)
    var environment = ProcessInfo.processInfo.environment
    environment.removeValue(forKey: "DYLD_LIBRARY_PATH")
    environment.removeValue(forKey: "DYLD_FALLBACK_LIBRARY_PATH")
    environment["XDG_CONFIG_HOME"] = configuration.deletingLastPathComponent().path
    environment["XDG_STATE_HOME"] = configuration.deletingLastPathComponent()
      .appendingPathComponent("state", isDirectory: true).path
    environment["TERM"] = "xterm-256color"
    environment["COLORTERM"] = "truecolor"
    let child = try NativePTYConnection(executable: tools.btop.path,
                       arguments: ["-c", configuration.path, "--themes-dir", tools.themes.path],
                       environment: environment.map { "\($0.key)=\($0.value)" }, bridge: output)
    process = child
    bridge = output
    writeLog("Started native btop (PID \(child.pid))")
    return TerminalEndpoint(runtime: self, output: output)
  }

  func send(_ data: Data) {
    guard let process, bridge?.hasTerminated == false else { return }
    process.send(data)
  }

  func resize() {
    guard let process, let bridge, !bridge.hasTerminated else { return }
    var size = bridge.getWindowSize()
    _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.descriptor, windowSize: &size)
  }

  func stop() async {
    if let stopTask { _ = await stopTask.value; return }
    guard let process, let bridge else { return }
    bridge.suppressTerminationCallback()
    let pid = process.pid
    let task = Task {
      if !bridge.hasTerminated { kill(pid, SIGINT) }
      await Self.waitForExit(bridge, seconds: 3)
      let graceful = bridge.exitedSuccessfully
      if !bridge.hasTerminated {
        kill(pid, SIGKILL)
        await Self.waitForExit(bridge, seconds: 1)
      }
      return graceful
    }
    stopTask = task
    lastStopWasGraceful = await task.value
    self.process = nil
    self.bridge = nil
    stopTask = nil
    writeLog("Stopped native btop")
  }

  func shutdown() async {
    shuttingDown = true
    await stop()
  }

  func stopForThemeChange(_ theme: String) async throws {
    try BtopThemeStore.validateThemeValue(theme)
    guard !shuttingDown, process != nil, stopTask == nil else { throw TerminalRuntimeError.alreadyRunning }
    let store = BtopThemeStore(configurationStore: configurationStore, bundledThemes: tools.themes)
    guard try store.availableThemes().contains(where: { $0.value == theme }) else {
      throw BtopThemeImportError.invalidTheme
    }
    guard try configurationStore.configurationSavingEnabled() else {
      throw TerminalRuntimeError.configurationSavingDisabled
    }
    await stop()
    guard lastStopWasGraceful else { throw TerminalRuntimeError.unsafeThemeChange }
  }

  func recoverAfterThemeChange(onTermination: (@Sendable () -> Void)?) throws -> TerminalEndpoint? {
    guard !shuttingDown, process == nil, stopTask == nil else { return nil }
    return try start(onTermination: onTermination)
  }

  func startWithTheme(_ theme: String, onTermination: (@Sendable () -> Void)?) throws -> TerminalEndpoint {
    guard !shuttingDown, process == nil, stopTask == nil else { throw TerminalRuntimeError.alreadyRunning }
    guard lastStopWasGraceful else { throw TerminalRuntimeError.unsafeThemeChange }
    let store = BtopThemeStore(configurationStore: configurationStore, bundledThemes: tools.themes)
    guard try store.availableThemes().contains(where: { $0.value == theme }) else {
      throw BtopThemeImportError.invalidTheme
    }
    try configurationStore.setTheme(theme)
    return try start(onTermination: onTermination)
  }

  private static func waitForExit(_ bridge: NativeProcessBridge, seconds: Int) async {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(seconds))
    while !bridge.hasTerminated && clock.now < deadline {
      try? await Task.sleep(for: .milliseconds(20))
    }
  }

  private func writeLog(_ message: String) {
    try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(),
                                           withIntermediateDirectories: true)
    if !FileManager.default.fileExists(atPath: logURL.path) {
      FileManager.default.createFile(atPath: logURL.path, contents: nil)
    }
    guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
    defer { try? handle.close() }
    _ = try? handle.seekToEnd()
    try? handle.write(contentsOf: Data("\(Date()): \(message)\n".utf8))
  }
}

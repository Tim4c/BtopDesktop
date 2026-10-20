import AppKit
import ApplicationServices

@MainActor
final class DesktopOverviewMonitor {
  private var timer: Timer?
  private var failedReads = 0
  private var reading = false
  private let onChange: (DesktopOverviewState) -> Void

  init(onChange: @escaping (DesktopOverviewState) -> Void) { self.onChange = onChange }

  func start() {
    guard timer == nil else { return }
    Task { await poll() }
    let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
      Task { @MainActor in await self?.poll() }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func poll() async {
    guard !reading else { return }
    guard AXIsProcessTrusted() else { onChange(.desktop); return }
    guard let dock = NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.dock").first else { onChange(.desktop); return }
    let processID = dock.processIdentifier
    reading = true
    defer { reading = false }
    let result = await Task.detached(priority: .utility) { Self.readState(processID: processID) }.value
    guard let state = result else {
      failedReads += 1
      if failedReads >= 3 { onChange(.desktop) }
      return
    }
    failedReads = 0
    onChange(state)
  }

  nonisolated private static func readState(processID: pid_t) -> DesktopOverviewState? {
    let root = AXUIElementCreateApplication(processID)
    AXUIElementSetMessagingTimeout(root, 0.05)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &value) == .success,
          let children = value as? [AXUIElement] else { return nil }
    var identifiers: [String] = []
    for child in children {
      var identifier: CFTypeRef?
      if AXUIElementCopyAttributeValue(child, kAXIdentifierAttribute as CFString, &identifier) == .success,
         let identifier = identifier as? String {
        identifiers.append(identifier)
      }
    }
    return DesktopOverviewState.detected(in: identifiers)
  }

  isolated deinit { timer?.invalidate() }
}

import AppKit

@MainActor
final class DesktopPanel: NSPanel {
  var allowsInteraction = false
  private(set) var hasExplicitClickFocus = false
  private var reportedEscapeFilterFailure = false
  private lazy var escapeFilter = TerminalEscapeFilter { [weak self] in
    self?.escapeReceiver
  }
  private var escapeReceiver: NativeTerminalView? {
    guard allowsInteraction, hasExplicitClickFocus, isKeyWindow else { return nil }
    return firstResponder as? NativeTerminalView
  }
  override var canBecomeKey: Bool { allowsInteraction && hasExplicitClickFocus }
  override var canBecomeMain: Bool { allowsInteraction && hasExplicitClickFocus }

  override func sendEvent(_ event: NSEvent) {
    // Authorize focus before AppKit handles this click; never on window restoration.
    if allowsInteraction && event.type == .leftMouseDown {
      hasExplicitClickFocus = true
    }
    super.sendEvent(event)
  }

  override func resignKey() {
    hasExplicitClickFocus = false
    super.resignKey()
  }

  func enableEscapeHandling() {
    guard allowsInteraction, hasExplicitClickFocus, isKeyWindow else { return }
    guard !escapeFilter.start(), !reportedEscapeFilterFailure else { return }
    reportedEscapeFilterFailure = true
    let alert = NSAlert()
    alert.messageText = "Allow exclusive Escape handling"
    alert.informativeText = "Enable Btop Desktop in System Settings → Privacy & Security → "
      + "Accessibility, then click the terminal again. Until access is granted, Escape may also "
      + "close Show Desktop. If access is already enabled, relaunch the app."
    alert.addButton(withTitle: "OK")
    alert.beginSheetModal(for: self)
  }

  func prepareEscapeHandling() {
    // Install before Show Desktop can start; requesting access still requires a terminal click.
    _ = escapeFilter.start(requestAccess: false)
  }

  func clearClickFocus() {
    resignKey()
    resignMain()
  }
}

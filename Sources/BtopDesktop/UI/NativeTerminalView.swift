import AppKit
import SwiftTerm

@MainActor
final class NativeTerminalView: TerminalView {
  override func mouseDown(with event: NSEvent) {
    guard let panel = window as? DesktopPanel, panel.allowsInteraction else { return }
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
    window?.makeFirstResponder(self)
    panel.enableEscapeHandling()
    super.mouseDown(with: event)
  }
}

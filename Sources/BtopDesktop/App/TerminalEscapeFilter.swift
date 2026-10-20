import AppKit
@preconcurrency import ApplicationServices

@MainActor
final class TerminalEscapeFilter {
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var capturedPress = false
  private var requestedAccess = false
  private let receiver: () -> NSResponder?

  init(receiver: @escaping () -> NSResponder?) {
    self.receiver = receiver
  }

  func start(requestAccess: Bool = true) -> Bool {
    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: true)
      return true
    }
    let prompt = requestAccess && !requestedAccess
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
      as CFDictionary
    if prompt { requestedAccess = true }
    guard AXIsProcessTrustedWithOptions(options) else { return false }
    let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
      | (CGEventMask(1) << CGEventType.keyUp.rawValue)
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
      eventsOfInterest: mask, callback: { _, type, event, context in
        guard let context else { return Unmanaged.passUnretained(event) }
        // The tap's source is installed only on the main run loop.
        let consumed = MainActor.assumeIsolated {
          let filter = Unmanaged<TerminalEscapeFilter>.fromOpaque(context).takeUnretainedValue()
          return filter.handle(type: type, event: event)
        }
        return consumed ? nil : Unmanaged.passUnretained(event)
      }, userInfo: Unmanaged.passUnretained(self).toOpaque()
    ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
      return false
    }
    eventTap = tap
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
  }

  func handle(type: CGEventType, event: CGEvent) -> Bool {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      capturedPress = false
      if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
      return false
    }
    guard type == .keyDown || type == .keyUp,
          event.getIntegerValueField(.keyboardEventKeycode) == 53 else { return false }
    if type == .keyUp {
      guard capturedPress else { return false }
      capturedPress = false
      if let target = receiver(), let keyEvent = escapeEvent(event, type: .keyUp) {
        target.keyUp(with: keyEvent)
      }
      return true
    }
    let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    guard capturedPress || event.flags.isDisjoint(with: modifiers) else { return false }
    guard let target = receiver(), let keyEvent = escapeEvent(event, type: .keyDown) else {
      return capturedPress
    }
    capturedPress = true
    target.keyDown(with: keyEvent)
    return true
  }

  private func escapeEvent(_ event: CGEvent, type: NSEvent.EventType) -> NSEvent? {
    // SwiftTerm identifies Escape by its character; Quartz events may omit Unicode text.
    NSEvent.keyEvent(
      with: type, location: .zero,
      modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)),
      timestamp: TimeInterval(event.timestamp) / 1_000_000_000, windowNumber: 0, context: nil,
      characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
      isARepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0, keyCode: 53)
  }

  isolated deinit {
    if let eventTap { CFMachPortInvalidate(eventTap) }
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
  }
}

import Darwin
import Foundation
import SwiftTerm

/// Serializes PTY delivery and buffers output until the terminal view is attached.
final class NativeProcessBridge: @unchecked Sendable {
  private let lock = NSLock()
  private var size = winsize(ws_row: 35, ws_col: 100, ws_xpixel: 0, ws_ypixel: 0)
  private var buffered = Data()
  private var sink: (@Sendable (Data) -> Void)?
  private var termination: (@Sendable () -> Void)?
  private var finished = false
  private var exitStatus: Int32?

  init(onTermination: (@Sendable () -> Void)?) { termination = onTermination }

  var hasTerminated: Bool { lock.withLock { finished } }
  var exitedSuccessfully: Bool { lock.withLock { finished && exitStatus == 0 } }

  func attach(_ sink: @escaping @Sendable (Data) -> Void) {
    lock.withLock {
      self.sink = sink
      if !buffered.isEmpty { sink(buffered) }
      buffered.removeAll()
    }
  }

  func suppressTerminationCallback() { lock.withLock { termination = nil } }

  func updateSize(columns: Int, rows: Int, width: Int, height: Int) {
    lock.withLock {
      size = winsize(ws_row: UInt16(clamping: rows), ws_col: UInt16(clamping: columns),
                     ws_xpixel: UInt16(clamping: width), ws_ypixel: UInt16(clamping: height))
    }
  }

  func getWindowSize() -> winsize { lock.withLock { size } }

  func dataReceived(slice: ArraySlice<UInt8>) {
    lock.withLock {
      let data = Data(slice)
      if let sink { sink(data) } else { buffered.append(data) }
    }
  }

  func processTerminated(status: Int32 = 0) {
    let callback = lock.withLock {
      finished = true
      exitStatus = status
      let callback = termination
      termination = nil
      return callback
    }
    callback?()
  }
}

struct TerminalEndpoint: Sendable {
  let runtime: TerminalRuntime
  let output: NativeProcessBridge
}

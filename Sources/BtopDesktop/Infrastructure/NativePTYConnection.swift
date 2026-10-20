import Darwin
import Foundation
import NativePTYSupport

/// Descriptor ownership and all input buffering stay on one serial IO queue.
final class NativePTYConnection: @unchecked Sendable {
  let pid: pid_t
  let descriptor: Int32
  private let bridge: NativeProcessBridge
  private let queue = DispatchQueue(label: "BtopDesktop.native-pty")
  private let reader: DispatchSourceRead
  private let monitor: DispatchSourceProcess
  private let writer: DispatchSourceWrite
  private var writerSuspended = true
  private var pendingInput = Data()

  init(executable: String, arguments: [String], environment: [String],
       bridge: NativeProcessBridge) throws {
    self.bridge = bridge
    var size = bridge.getWindowSize()
    var ptyDescriptor: Int32 = -1
    var argv = ([executable] + arguments).map { strdup($0) } + [nil]
    var env = environment.map { strdup($0) } + [nil]
    defer {
      argv.compactMap { $0 }.forEach { free($0) }
      env.compactMap { $0 }.forEach { free($0) }
    }
    let child = executable.withCString { binary in
      argv.withUnsafeMutableBufferPointer { arguments in
        env.withUnsafeMutableBufferPointer { environment in
          native_pty_spawn(binary, arguments.baseAddress, environment.baseAddress, &size, &ptyDescriptor)
        }
      }
    }
    guard child > 0, ptyDescriptor >= 0 else { throw TerminalRuntimeError.launchFailed }
    pid = child
    descriptor = ptyDescriptor
    reader = DispatchSource.makeReadSource(fileDescriptor: ptyDescriptor, queue: queue)
    monitor = DispatchSource.makeProcessSource(identifier: child, eventMask: .exit, queue: queue)
    writer = DispatchSource.makeWriteSource(fileDescriptor: ptyDescriptor, queue: queue)
    reader.setEventHandler {
      var buffer = [UInt8](repeating: 0, count: 65536)
      while true {
        let count = read(ptyDescriptor, &buffer, buffer.count)
        if count > 0 {
          bridge.dataReceived(slice: buffer.prefix(count))
        } else if count < 0 && errno == EINTR {
          continue
        } else { break }
      }
    }
    reader.setCancelHandler { close(ptyDescriptor) }
    monitor.setEventHandler {
      var status: Int32 = 0
      var result: pid_t
      repeat { result = waitpid(child, &status, 0) } while result < 0 && errno == EINTR
      bridge.processTerminated(status: result == child ? status : -1)
    }
    writer.setEventHandler { [weak self] in self?.flushInput() }
    reader.resume()
    monitor.resume()
  }

  deinit {
    reader.cancel()
    monitor.cancel()
    if writerSuspended { writer.resume() }
    writer.cancel()
    if !bridge.hasTerminated {
      let child = pid
      kill(child, SIGKILL)
      DispatchQueue.global().async {
        var status: Int32 = 0
        _ = waitpid(child, &status, 0)
      }
    }
  }

  func send(_ data: Data) {
    queue.async { [weak self] in
      guard let self, !self.bridge.hasTerminated else { return }
      self.pendingInput.append(data)
      self.flushInput()
    }
  }

  private func flushInput() {
    while !pendingInput.isEmpty && !bridge.hasTerminated {
      let count = pendingInput.withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
      if count > 0 {
        pendingInput.removeFirst(count)
      } else if count < 0 && errno == EINTR {
        continue
      } else if count < 0 && errno == EAGAIN {
        if writerSuspended { writerSuspended = false; writer.resume() }
        return
      } else { pendingInput.removeAll(); break }
    }
    if !writerSuspended { writerSuspended = true; writer.suspend() }
  }
}

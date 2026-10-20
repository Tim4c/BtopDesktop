import Foundation
@testable import BtopDesktop

final class NativeTestFileManager: FileManager, @unchecked Sendable {
  let root: URL
  init(root: URL) { self.root = root }
  override func urls(for directory: FileManager.SearchPathDirectory,
                     in domainMask: FileManager.SearchPathDomainMask) -> [URL] { [root] }
  override var homeDirectoryForCurrentUser: URL { root }
}

struct NativeFixture {
  let directory: URL
  let runtime: TerminalRuntime

  init(ignoreInterrupt: Bool = false) throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let binary = directory.appendingPathComponent("btop")
    let code = """
      #!/usr/bin/python3
      import signal, sys, time, tty, os, struct, fcntl, termios
      from pathlib import Path
      configuration = Path(sys.argv[sys.argv.index('-c') + 1])
      tty.setraw(sys.stdin.fileno())
      def stop(signum, frame):
          configuration.write_text('saved_on_sigint = true\\n')
          sys.exit(0)
      signal.signal(signal.SIGINT, signal.SIG_IGN if \(ignoreInterrupt ? "True" : "False") else stop)
      def draw(signum=None, frame=None):
          rows, cols, _, _ = struct.unpack('HHHH', fcntl.ioctl(0, termios.TIOCGWINSZ, bytes(8)))
          sys.stdout.write('\\x1b[2J\\x1b[H\\x1b[31mcpu fixture %dx%d\\x1b[0m' % (cols, rows))
          sys.stdout.flush()
      signal.signal(signal.SIGWINCH, draw)
      draw()
      while True:
          value = os.read(0, 1)
          if value == b'q': stop(0, None)
          if value == b'm':
              sys.stdout.write('\\x1b[2J\\x1b[HOPTIONS')
              sys.stdout.flush()
          if value == b'\\x1b': draw()
      """
    try code.write(to: binary, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
    runtime = TerminalRuntime(
      logDirectory: directory, tools: TerminalRuntimeTools(btop: binary, themes: directory),
      configurationStore: BtopConfigurationStore(fileManager: NativeTestFileManager(root: directory)))
  }

  func cleanup() { try? FileManager.default.removeItem(at: directory) }
}

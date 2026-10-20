import Foundation

struct TerminalRuntimeTools: Sendable {
  let btop: URL
  let themes: URL

  static var bundled: Self {
    guard let resources = Bundle.main.resourceURL else {
      fatalError("Application resources are unavailable.")
    }
    return Self(btop: resources.appendingPathComponent("bin/btop"),
                themes: resources.appendingPathComponent("themes"))
  }
}

import AppKit

@MainActor
final class SplashView: NSVisualEffectView {
  init() {
    super.init(frame: .zero)
    material = .hudWindow
    blendingMode = .behindWindow
    state = .active

    let wordmarkLines = [
      "██████╗ ████████╗ ██████╗ ██████╗",
      "██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗",
      "██████╔╝   ██║   ██║   ██║██████╔╝",
      "██╔══██╗   ██║   ██║   ██║██╔═══╝",
      "██████╔╝   ██║   ╚██████╔╝██║",
      "╚═════╝    ╚═╝    ╚═════╝ ╚═╝"
    ]

    let logo = NSTextField(wrappingLabelWithString: wordmarkLines.joined(separator: "\n"))
    logo.font = .monospacedSystemFont(ofSize: 16, weight: .medium)
    logo.textColor = NSColor(srgbRed: 137 / 255, green: 180 / 255, blue: 250 / 255, alpha: 1)
    logo.alignment = .left
    logo.maximumNumberOfLines = 0

    let stack = NSStackView(views: [logo])
    stack.orientation = .vertical
    stack.alignment = .centerX
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false

    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
  }

  required init?(coder: NSCoder) {
    nil
  }
}

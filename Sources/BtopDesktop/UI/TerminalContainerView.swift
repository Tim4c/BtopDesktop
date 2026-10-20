import AppKit

/// Centers whole terminal cells instead of leaving unused space on two edges.
@MainActor
final class TerminalContainerView: NSView {
  private let terminal: NativeTerminalView
  private var arrangingTerminal = false
  private let padding: CGFloat = 4

  init(terminal: NativeTerminalView) {
    self.terminal = terminal
    super.init(frame: .zero)
    addSubview(terminal)
  }

  required init?(coder: NSCoder) { nil }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    needsLayout = true
  }

  override func layout() {
    super.layout()
    guard !arrangingTerminal else { return }
    arrangingTerminal = true
    defer { arrangingTerminal = false }
    let grid = terminal.getTerminal()
    let optimal = terminal.getOptimalFrameSize().size
    guard grid.cols > 0, grid.rows > 0 else { return }
    let cellWidth = optimal.width / CGFloat(grid.cols)
    let cellHeight = optimal.height / CGFloat(grid.rows)
    guard cellWidth > 0, cellHeight > 0 else { return }
    let columns = floor(max(0, bounds.width - 2 * padding) / cellWidth)
    let rows = floor(max(0, bounds.height - 2 * padding) / cellHeight)
    guard columns >= 1, rows >= 1 else { return }
    // Avoid floating-point division dropping the last cell during SwiftTerm resize.
    let width = (columns * cellWidth).nextUp
    let height = (rows * cellHeight).nextUp
    terminal.frame = NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2,
                            width: width, height: height)
  }
}

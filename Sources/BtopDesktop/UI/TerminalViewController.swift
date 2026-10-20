import AppKit
import CoreImage
import SwiftTerm

@MainActor
final class TerminalViewController: NSViewController, @preconcurrency TerminalViewDelegate {
  private let now: () -> Date
  private let maximumBlurRadius: CGFloat = 3
  private let terminal = NativeTerminalView(frame: .zero)
  private let splashView = SplashView()
  private var endpoint: TerminalEndpoint?
  private var generation = 0
  private var revealing = false
  private var revealTask: Task<Void, Never>?
  private var firstOutputTime: Date?
  private var lastOutputTime: Date?
  private var observedSynchronizedOutput = false
  private var hasDisplayUpdate = false
  private var synchronizingSize = false
  private var grayscaleFilter: CIFilter?
  private var overviewBlurRadius: CGFloat = 0
  private let overviewBlurFilter = CIFilter(name: "CIGaussianBlur")
  private var attachedFilters: [String] = []
  private(set) var isReady = false
  var onLoadStateChanged: (() -> Void)?

  init(now: @escaping () -> Date = Date.init) {
    self.now = now
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { nil }

  func show(endpoint: TerminalEndpoint) {
    loadViewIfNeeded()
    applyTerminalFilters()
    generation += 1
    let current = generation
    self.endpoint = endpoint
    revealTask?.cancel()
    revealTask = nil
    firstOutputTime = nil
    lastOutputTime = nil
    observedSynchronizedOutput = false
    hasDisplayUpdate = false
    isReady = false
    revealing = false
    terminal.alphaValue = 0
    splashView.isHidden = false
    splashView.alphaValue = 1
    onLoadStateChanged?()
    endpoint.output.attach { [weak self] data in
      RunLoop.main.perform(inModes: [.common]) {
        MainActor.assumeIsolated {
          guard let self, self.generation == current else { return }
          let now = self.now()
          self.firstOutputTime = self.firstOutputTime ?? now
          self.lastOutputTime = now
          self.terminal.feed(byteArray: Array(data)[...])
          self.observedSynchronizedOutput = self.observedSynchronizedOutput
            || self.terminal.getTerminal().synchronizedOutputActive
          self.scheduleReveal(generation: current)
        }
      }
    }
    synchronizeSize()
  }

  func setFontSize(_ size: CGFloat) {
    loadViewIfNeeded()
    guard terminal.font.pointSize != size else { return }
    terminal.font = NSFont(name: "Courier New", size: size)
      ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()
    synchronizeSize()
  }

  func setGrayscale(_ enabled: Bool) {
    guard let filter = CIFilter(name: "CIColorMatrix") else { return }
    // Use the W3C grayscale(100%) luminance coefficients.
    let luminance = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
    for channel in ["inputRVector", "inputGVector", "inputBVector"] {
      filter.setValue(luminance, forKey: channel)
    }
    grayscaleFilter = enabled ? filter : nil
    applyTerminalFilters(animated: true)
  }

  func setOverviewState(_ state: DesktopOverviewState) {
    let radius = state.isOverview ? maximumBlurRadius : 0
    guard overviewBlurRadius != radius else { return }
    loadViewIfNeeded()
    overviewBlurRadius = radius
    applyTerminalFilters()
  }

  private func applyTerminalFilters(animated: Bool = false) {
    CATransaction.begin()
    CATransaction.setDisableActions(!animated)
    CATransaction.setAnimationDuration(0.2)
    var filters = grayscaleFilter.map { [$0] } ?? []
    if overviewBlurRadius > 0, let blur = overviewBlurFilter {
      blur.name = "overviewBlur"
      filters.append(blur)
    }
    let names = filters.map(\.name)
    if attachedFilters != names {
      terminal.layer?.filters = filters
      attachedFilters = names
    }
    if overviewBlurRadius > 0 {
      // Core Animation must receive attached filter parameter changes through the layer.
      terminal.layer?.setValue(overviewBlurRadius, forKeyPath: "filters.overviewBlur.inputRadius")
    }
    CATransaction.commit()
  }

  func setOpacity(_ value: CGFloat) {
    guard isReady else { return }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      terminal.animator().alphaValue = value
    }
  }

  override func loadView() {
    view = TerminalContainerView(terminal: terminal)
    terminal.alphaValue = 0
    terminal.font = NSFont(name: "Courier New", size: 12)
      ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
    // SwiftTerm reclaims the scrollbar width when its NSScroller is hidden.
    terminal.subviews.compactMap { $0 as? NSScroller }.forEach { $0.isHidden = true }
    terminal.nativeBackgroundColor = .clear
    terminal.wantsLayer = true
    terminal.terminalDelegate = self
    terminal.notifyUpdateChanges = true
    splashView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(splashView)
    NSLayoutConstraint.activate([
      splashView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      splashView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      splashView.topAnchor.constraint(equalTo: view.topAnchor),
      splashView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  func synchronizeSize() {
    guard let endpoint, !synchronizingSize else { return }
    synchronizingSize = true
    defer { synchronizingSize = false }
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()
    let grid = terminal.getTerminal()
    endpoint.output.updateSize(columns: grid.cols, rows: grid.rows,
                               width: Int(terminal.bounds.width), height: Int(terminal.bounds.height))
    Task { await endpoint.runtime.resize() }
  }

  private func scheduleReveal(generation: Int) {
    guard !revealing, revealTask == nil else { return }
    revealTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        if let self {
          guard self.generation == generation else { return }
          if self.canReveal {
            self.reveal(generation: generation)
            if self.revealing { return }
          }
        } else {
          return
        }
        do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
      }
    }
  }

  private var canReveal: Bool {
    guard hasDisplayUpdate, !terminal.getTerminal().synchronizedOutputActive,
          let firstOutputTime, let lastOutputTime else { return false }
    let grid = terminal.getTerminal()
    guard (0..<grid.rows).contains(where: { row in
      let text = grid.getLine(row: row)?.translateToString(endCol: grid.cols) ?? ""
      return !text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters)).isEmpty
    }) else { return false }
    return observedSynchronizedOutput || now().timeIntervalSince(lastOutputTime) >= 0.08
      || now().timeIntervalSince(firstOutputTime) >= 1
  }

  private func reveal(generation: Int) {
    // An invisible view may skip normal drawing; render its current contents explicitly.
    guard let image = terminal.bitmapImageRepForCachingDisplay(in: terminal.bounds) else { return }
    terminal.cacheDisplay(in: terminal.bounds, to: image)
    revealing = true
    revealTask = nil
    isReady = true
    onLoadStateChanged?()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      self.splashView.animator().alphaValue = 0
    } completionHandler: { [weak self] in
      Task { @MainActor in
        guard let self, self.generation == generation else { return }
        self.splashView.isHidden = true
      }
    }
  }

  func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) { synchronizeSize() }
  func setTerminalTitle(source: TerminalView, title: String) {}
  func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
  func scrolled(source: TerminalView, position: Double) {}
  func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
    guard firstOutputTime != nil else { return }
    hasDisplayUpdate = true
  }
  func send(source: TerminalView, data: ArraySlice<UInt8>) {
    guard let endpoint else { return }
    let bytes = Data(data)
    Task { await endpoint.runtime.send(bytes) }
  }
}

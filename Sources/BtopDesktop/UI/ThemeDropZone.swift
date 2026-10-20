import AppKit

@MainActor
final class ThemeDropZone: NSButton {
  var onDrop: ((URL) -> Void)?
  private(set) var isDropHighlighted = false

  init(target: AnyObject?, action: Selector?) {
    super.init(frame: .zero)
    self.target = target
    self.action = action
    title = "Drop a btop theme here · Click to browse"
    isBordered = false
    wantsLayer = true
    layer?.cornerRadius = 8
    layer?.borderWidth = 1
    widthAnchor.constraint(equalToConstant: 412).isActive = true
    heightAnchor.constraint(equalToConstant: 44).isActive = true
    setAccessibilityLabel("Import btop theme")
    setAccessibilityHelp("Drop one .theme file here, or click to choose a file.")
    registerForDraggedTypes([.fileURL])
    updateHighlight(false)
  }

  required init?(coder: NSCoder) { nil }

  override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
    draggingUpdated(sender)
  }

  override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
    let accepts = sender.draggingSourceOperationMask.contains(.copy)
      && themeURL(from: sender.draggingPasteboard) != nil
    updateHighlight(accepts)
    return accepts ? .copy : []
  }

  override func draggingExited(_ sender: (any NSDraggingInfo)?) { updateHighlight(false) }

  override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    themeURL(from: sender.draggingPasteboard) != nil
  }

  override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    defer { updateHighlight(false) }
    guard let source = themeURL(from: sender.draggingPasteboard), let onDrop else { return false }
    onDrop(source)
    return true
  }

  override func concludeDragOperation(_ sender: (any NSDraggingInfo)?) { updateHighlight(false) }

  func themeURL(from pasteboard: NSPasteboard) -> URL? {
    guard pasteboard.pasteboardItems?.count == 1,
          let urls = pasteboard.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL],
          urls.count == 1, let source = urls.first,
          source.pathExtension.lowercased() == "theme",
          (try? source.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
    return source
  }

  private func updateHighlight(_ highlighted: Bool) {
    isDropHighlighted = highlighted
    layer?.borderColor = (highlighted ? NSColor.controlAccentColor : .separatorColor).cgColor
    layer?.backgroundColor = (highlighted
      ? NSColor.controlAccentColor.withAlphaComponent(0.18)
      : NSColor.controlBackgroundColor.withAlphaComponent(0.5)).cgColor
  }
}

import Foundation

enum DesktopMode: Equatable {
  case wallpaper
  case interactive
}

struct DesktopAppearanceState {
  enum Preview: Equatable {
    case none
    case theme
    case appearance(active: Bool)
    case cornerRadius(active: Bool?)
  }

  enum Resize: Equatable {
    case idle
    case automatic
    case manual
  }

  var mode: DesktopMode = .wallpaper
  var preview: Preview = .none
  var resize: Resize = .idle

  func isActive(hasExplicitClickFocus: Bool, isKeyWindow: Bool) -> Bool {
    switch preview {
    case .appearance(let active): return active
    case .cornerRadius(let active):
      if let active { return active }
    case .none, .theme: break
    }
    return mode == .interactive && hasExplicitClickFocus && isKeyWindow
  }

  func grayscaleEnabled(configured: Bool) -> Bool {
    preview != .theme && configured
  }

  func showsGuide(configuredBorder: Bool) -> Bool {
    if resize == .manual { return true }
    if case .cornerRadius = preview { return !configuredBorder }
    return false
  }

  mutating func previewCornerRadius() {
    let active: Bool?
    switch preview {
    case .appearance(let value), .cornerRadius(.some(let value)): active = value
    default: active = nil
    }
    preview = .cornerRadius(active: active)
  }

  mutating func clearTransientState() {
    preview = .none
    resize = .idle
  }
}

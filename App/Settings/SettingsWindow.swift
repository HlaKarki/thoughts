import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
  static let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]

  private var window: NSWindow?
  private var model: SettingsModel?
  private let makeModel: @MainActor () -> SettingsModel
  private let front: WindowFront

  init(front: WindowFront = .live, makeModel: @escaping @MainActor () -> SettingsModel) {
    self.front = front
    self.makeModel = makeModel
  }

  func show() {
    let model = self.model ?? makeModel()
    self.model = model
    model.refresh()
    let window = self.window ?? makeWindow(model: model)
    self.window = window
    front.bring(window)
  }

  func makeWindow(model: SettingsModel) -> NSWindow {
    let window = NSWindow(
      contentRect: CGRect(origin: .zero, size: SettingsView.size),
      styleMask: Self.styleMask,
      backing: .buffered,
      defer: false)
    window.title = String(localized: "Thoughts Settings")
    window.isReleasedWhenClosed = false
    window.animationBehavior = .none
    let hosting = NSHostingView(rootView: SettingsView(model: model))
    hosting.sizingOptions = []
    window.contentView = hosting
    window.center()
    return window
  }
}

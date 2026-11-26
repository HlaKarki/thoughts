import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
  static let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]

  private var window: NSWindow?
  private var model: SettingsModel?
  private let makeModel: @MainActor () -> SettingsModel
  private let front: WindowFront
  private let returns: FrontReturn?

  init(
    front: WindowFront = .live, returns: FrontReturn? = nil,
    makeModel: @escaping @MainActor () -> SettingsModel
  ) {
    self.front = front
    self.returns = returns
    self.makeModel = makeModel
  }

  func show() {
    let model = self.model ?? makeSettingsModel()
    self.model = model
    model.refresh()
    let window = self.window ?? makeWindow(model: model)
    self.window = window
    front.bring(window)
  }

  private func makeSettingsModel() -> SettingsModel {
    let model = makeModel()
    if let returns {
      model.hooks = returns.hooks { [weak self] in self?.returnToFront() }
    }
    return model
  }

  private func returnToFront() {
    guard let window else { return }
    front.bringIfShown(window)
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

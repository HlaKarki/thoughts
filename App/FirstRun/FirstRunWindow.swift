import AppKit
import SwiftUI

@MainActor
final class FirstRunWindowController {
  static let styleMask: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]

  private var window: NSWindow?
  private let makeModel: @MainActor () -> FirstRunModel
  private let visibility: AppVisibility

  init(visibility: AppVisibility = .live, makeModel: @escaping @MainActor () -> FirstRunModel) {
    self.visibility = visibility
    self.makeModel = makeModel
  }

  func show() {
    if let window {
      NSApp.activate()
      visibility.revealBeforeOrderingFront()
      window.makeKeyAndOrderFront(nil)
      return
    }
    let model = makeModel()
    let finish = model.onFinish
    model.onFinish = { [weak self] in
      self?.close()
      finish()
    }
    let window = makeWindow(model: model)
    self.window = window
    NSApp.activate()
    visibility.revealBeforeOrderingFront()
    window.makeKeyAndOrderFront(nil)
  }

  private func close() {
    window?.close()
    window = nil
  }

  func makeWindow(model: FirstRunModel) -> NSWindow {
    let window = NSWindow(
      contentRect: CGRect(origin: .zero, size: FirstRunView.size),
      styleMask: Self.styleMask,
      backing: .buffered,
      defer: false)
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isReleasedWhenClosed = false
    window.animationBehavior = .none
    let hosting = NSHostingView(rootView: FirstRunView(model: model))
    hosting.sizingOptions = []
    window.contentView = hosting
    window.center()
    return window
  }
}

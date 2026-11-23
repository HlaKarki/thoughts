import AppKit
import SwiftUI

@MainActor
final class FirstRunWindowController {
  private var window: NSWindow?
  private let makeModel: @MainActor () -> FirstRunModel

  init(makeModel: @escaping @MainActor () -> FirstRunModel) {
    self.makeModel = makeModel
  }

  func show() {
    if let window {
      NSApp.activate()
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
    window.makeKeyAndOrderFront(nil)
  }

  private func close() {
    window?.close()
    window = nil
  }

  private func makeWindow(model: FirstRunModel) -> NSWindow {
    let window = NSWindow(
      contentRect: CGRect(origin: .zero, size: FirstRunView.size),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false)
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isReleasedWhenClosed = false
    let hosting = NSHostingView(rootView: FirstRunView(model: model))
    hosting.sizingOptions = []
    window.contentView = hosting
    window.center()
    return window
  }
}

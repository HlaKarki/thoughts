import AppKit
import SwiftUI

struct RightClickCatcher: NSViewRepresentable {
  let onRightClick: () -> Void

  func makeNSView(context: Context) -> CatcherView {
    CatcherView()
  }

  func updateNSView(_ view: CatcherView, context: Context) {
    view.onRightClick = onRightClick
  }

  final class CatcherView: NSView {
    var onRightClick: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
      guard NSApp.currentEvent?.type == .rightMouseDown else { return nil }
      return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) {
      onRightClick?()
    }
  }
}

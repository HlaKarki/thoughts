import AppKit
import SwiftUI

struct PointerTracker: NSViewRepresentable {
  let onMove: (CGPoint?) -> Void

  func makeNSView(context: Context) -> TrackerView {
    TrackerView()
  }

  func updateNSView(_ view: TrackerView, context: Context) {
    view.onMove = onMove
  }

  final class TrackerView: NSView {
    static let options: NSTrackingArea.Options = [
      .mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect,
    ]

    var onMove: ((CGPoint?) -> Void)?

    override init(frame: NSRect) {
      super.init(frame: frame)
      addTrackingArea(NSTrackingArea(rect: .zero, options: Self.options, owner: self))
    }

    required init?(coder: NSCoder) {
      nil
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
      nil
    }

    override func mouseEntered(with event: NSEvent) {
      track(windowPoint: event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
      track(windowPoint: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
      track(windowPoint: nil)
    }

    func track(windowPoint: CGPoint?) {
      onMove?(windowPoint.map { convert($0, from: nil) })
    }
  }
}

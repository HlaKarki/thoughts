import AppKit
import SwiftUI

struct PanelGrabArea: NSViewRepresentable {
  func makeNSView(context: Context) -> PanelGrabView {
    PanelGrabView()
  }

  func updateNSView(_ view: PanelGrabView, context: Context) {}
}

final class PanelGrabView: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    (window as? ThoughtsPanel)?.findingGrabArea == true ? super.hitTest(point) : nil
  }
}

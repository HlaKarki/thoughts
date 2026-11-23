import AppKit
import SwiftUI

struct PanelBackground: View {
  static var cornerRadius: CGFloat {
    if #available(macOS 26, *) { 24 } else { 12 }
  }

  var body: some View {
    if #available(macOS 26, *) {
      Color.clear.glassEffect(.regular, in: .rect(cornerRadius: Self.cornerRadius))
    } else {
      TranslucentMaterial()
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
  }
}

private struct TranslucentMaterial: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .popover
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

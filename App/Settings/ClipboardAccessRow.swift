import AppKit
import SwiftUI

struct ClipboardAccessRow: View {
  let model: SettingsModel

  static func title(for behavior: NSPasteboard.AccessBehavior) -> LocalizedStringKey {
    switch behavior {
    case .alwaysAllow: "Always allow"
    case .alwaysDeny: "Never allow"
    default: "Ask each time"
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      Text("Paste from other apps")
        .font(.system(size: 13))
        .foregroundStyle(Color(nsColor: .labelColor))
      Spacer(minLength: 8)
      Text(Self.title(for: model.clipboardAccess))
        .font(.system(size: 13))
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
      Button("Open Privacy & Security") { model.openClipboardSettings() }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 12)
  }
}

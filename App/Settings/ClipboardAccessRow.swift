import AppKit
import SwiftUI

struct ClipboardAccessRow: View {
  let model: SettingsModel

  static func title(for behavior: NSPasteboard.AccessBehavior) -> LocalizedStringKey {
    switch behavior {
    case .alwaysAllow: "Allow"
    case .alwaysDeny: "Deny"
    default: "Ask"
    }
  }

  static func showsSettingsButton(for behavior: NSPasteboard.AccessBehavior) -> Bool {
    behavior != .alwaysAllow
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
      if Self.showsSettingsButton(for: model.clipboardAccess) {
        Button("Open Privacy & Security") { model.openClipboardSettings() }
      }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 12)
  }
}

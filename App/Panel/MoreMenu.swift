import AppKit
import SwiftUI

struct MoreMenu: View {
  @Bindable var preferences: Preferences
  var onClearDone: (() -> Void)?
  var onOpenSettings: (() -> Void)?
  var onCheckForUpdates: (() -> Void)?

  var body: some View {
    Menu {
      Toggle("Keep open", isOn: $preferences.keepOpen)
      Button("Clear done") { onClearDone?() }
        .disabled(onClearDone == nil)
      Divider()
      Button("Settings…") { onOpenSettings?() }
        .disabled(onOpenSettings == nil)
      Button("Check for updates…") { onCheckForUpdates?() }
        .disabled(onCheckForUpdates == nil)
      Divider()
      Button("Quit Thoughts") { NSApp.terminate(nil) }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color(nsColor: .systemGray))
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .fixedSize()
  }
}

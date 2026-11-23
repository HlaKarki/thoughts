import AppKit
import SwiftUI

struct MoreMenu: View {
  @Bindable var preferences: Preferences
  var onClearDone: (() -> Void)?
  var onOpenSettings: (() -> Void)?
  var onCheckForUpdates: (() -> Void)?
  var updateAvailable = false

  static let dotSize: CGFloat = 6

  var body: some View {
    Menu {
      if updateAvailable {
        Button("Update available") { onCheckForUpdates?() }
        Divider()
      }
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
        .overlay(alignment: .topTrailing) {
          if updateAvailable {
            Circle()
              .fill(Color(nsColor: .controlAccentColor))
              .frame(width: Self.dotSize, height: Self.dotSize)
              .padding(6)
          }
        }
        .contentShape(Rectangle())
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .fixedSize()
  }
}

import AppKit
import SwiftUI

struct MoreMenu: View {
  @Bindable var preferences: Preferences
  let shared: SharedMenuItems
  var onClearDone: (() -> Void)?

  private var updateAvailable: Bool { shared.isUpdateWaiting }

  static let dotSize: CGFloat = 6

  var body: some View {
    Menu {
      if let update = shared.updateAvailable {
        SharedMenuButton(item: update)
        Divider()
      }
      Toggle("Keep open", isOn: $preferences.keepOpen)
      Button("Clear done") { onClearDone?() }
        .disabled(onClearDone == nil)
      Divider()
      SharedMenuButton(item: shared.settings)
      SharedMenuButton(item: shared.checkForUpdates)
      Divider()
      SharedMenuButton(item: shared.quit)
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

private struct SharedMenuButton: View {
  let item: SharedMenuItem

  var body: some View {
    Button(item.title) { item.perform() }
      .keyboardShortcut(item.key?.shortcut)
      .disabled(!item.isEnabled)
  }
}

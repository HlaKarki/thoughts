import SwiftUI

struct EmptyListView: View {
  let preferences: Preferences
  @State private var shortcut = CaptureMethod.captureShortcutText

  private var message: Text {
    guard let keycap = preferences.captureMethod.keycap(shortcut: shortcut) else {
      return Text("Type below and press Return to add one.")
    }
    return Text(
      "Type below and press Return to add one. In any app, press \(keycap.inline) to save the selected text or a copied image."
    )
  }

  var body: some View {
    VStack(spacing: 6) {
      Text("No thoughts yet")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color(nsColor: .labelColor))
      message
        .font(.system(size: 12))
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        .multilineTextAlignment(.center)
        .lineSpacing(3)
    }
    .padding(.horizontal, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onReceive(NotificationCenter.default.publisher(for: .captureShortcutChanged)) { _ in
      shortcut = CaptureMethod.captureShortcutText
    }
  }
}

struct NoMatchesView: View {
  var body: some View {
    Text("No thoughts found")
      .font(.system(size: 13))
      .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

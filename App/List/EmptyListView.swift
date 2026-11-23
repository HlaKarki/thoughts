import SwiftUI

struct EmptyListView: View {
  var body: some View {
    VStack(spacing: 6) {
      Text("No thoughts yet")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color(nsColor: .labelColor))
      Text(
        "Type below and press Return to add one. In any app, press ⇧⇧ to save the selected text or a copied image."
      )
      .font(.system(size: 12))
      .foregroundStyle(Color(nsColor: .secondaryLabelColor))
      .multilineTextAlignment(.center)
      .lineSpacing(3)
    }
    .padding(.horizontal, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

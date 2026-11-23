import SwiftUI

struct HintLine: View {
  let text: String?

  var body: some View {
    Text(verbatim: text ?? " ")
      .font(.system(size: 12))
      .foregroundStyle(Color(nsColor: .secondaryLabelColor))
      .lineLimit(1)
      .truncationMode(.middle)
      .padding(.horizontal, 10)
      .frame(height: 24)
      .background(.regularMaterial, in: Capsule())
      .overlay { Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1) }
      .padding(.horizontal, 12)
      .padding(.bottom, 8)
      .opacity(text == nil ? 0 : 1)
      .allowsHitTesting(false)
      .accessibilityHidden(text == nil)
      .animation(.easeOut(duration: 0.2), value: text)
  }
}

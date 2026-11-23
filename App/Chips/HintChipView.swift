import SwiftUI

struct ChipSurface<Content: View>: View {
  static var size: CGSize { CGSize(width: 300, height: 60) }

  @Environment(\.colorScheme) private var colorScheme
  @ViewBuilder let content: Content

  var body: some View {
    HStack(spacing: 10) {
      content
    }
    .padding(.leading, 10)
    .padding(.trailing, 12)
    .frame(width: Self.size.width, height: Self.size.height)
    .background(
      colorScheme == .dark ? Color(white: 0.165) : Color.white,
      in: RoundedRectangle(cornerRadius: 14, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(
          colorScheme == .dark ? Color(white: 0.267) : Color(white: 0.922), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    .shadow(color: .black.opacity(0.16), radius: 15, y: 10)
  }
}

struct ChipSlot<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  @ViewBuilder let content: Content

  var body: some View {
    content
      .frame(width: 40, height: 40)
      .background(
        colorScheme == .dark ? Color(white: 0.227) : Color(white: 0.933),
        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
  }
}

struct ChipText: View {
  let title: LocalizedStringKey
  let message: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color(nsColor: .labelColor))
        .lineLimit(1)
        .frame(height: 18, alignment: .leading)
      if let message {
        Text(verbatim: message)
          .font(.system(size: 12))
          .foregroundStyle(Color(nsColor: .secondaryLabelColor))
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
          .frame(minHeight: 16, alignment: .topLeading)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct HintChipView: View {
  enum Kind: Equatable {
    case saved
    case alreadySaved
    case nothingToSave
    case failed(String)
  }

  let kind: Kind

  var body: some View {
    ChipSurface {
      ChipSlot {
        Image(systemName: symbol)
          .font(.system(size: 18))
          .foregroundStyle(tint)
      }
      switch kind {
      case .saved:
        ChipText(title: "Saved", message: nil)
      case .alreadySaved:
        ChipText(
          title: "Already saved", message: String(localized: "It is already in your thoughts"))
      case .nothingToSave:
        ChipText(
          title: "Nothing to save", message: String(localized: "Select text or copy an image first")
        )
      case .failed(let message):
        ChipText(title: "Couldn't save", message: message)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var symbol: String {
    switch kind {
    case .saved: "checkmark.circle"
    case .alreadySaved, .nothingToSave: "info.circle"
    case .failed: "exclamationmark.triangle"
    }
  }

  private var tint: Color {
    switch kind {
    case .saved: Color(nsColor: .systemGreen)
    case .alreadySaved, .nothingToSave: Color(nsColor: .systemGray)
    case .failed: Color(nsColor: .systemOrange)
    }
  }
}

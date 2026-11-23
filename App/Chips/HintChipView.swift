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

struct ChipThumbnail: View {
  let image: NSImage

  var body: some View {
    Image(nsImage: image)
      .resizable()
      .scaledToFill()
      .frame(width: 40, height: 40)
      .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      .accessibilityHidden(true)
  }
}

struct HintChipView: View {
  enum Kind: Equatable {
    case saved(SavedPreview)
    case alreadySaved(SavedPreview)
    case nothingToSave
    case failed(String)
  }

  let kind: Kind

  var body: some View {
    ChipSurface {
      if let thumbnail {
        ChipSlot { ChipThumbnail(image: thumbnail) }
      }
      ChipText(title: titleKey, message: line)
        .padding(.leading, thumbnail == nil ? 6 : 0)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(spokenText)
  }

  var spokenText: String {
    guard let line else { return titleText }
    return "\(titleText), \(line)"
  }

  var thumbnail: NSImage? {
    switch kind {
    case .saved(let preview), .alreadySaved(let preview): preview.thumbnail
    case .nothingToSave, .failed: nil
    }
  }

  var line: String? {
    switch kind {
    case .saved(let preview), .alreadySaved(let preview): preview.line
    case .nothingToSave: String(localized: "Select text or copy an image first")
    case .failed(let message): message
    }
  }

  private var titleKey: LocalizedStringKey {
    switch kind {
    case .saved: "Saved"
    case .alreadySaved: "Already saved"
    case .nothingToSave: "Nothing to save"
    case .failed: "Couldn't save"
    }
  }

  private var titleText: String {
    switch kind {
    case .saved: String(localized: "Saved")
    case .alreadySaved: String(localized: "Already saved")
    case .nothingToSave: String(localized: "Nothing to save")
    case .failed: String(localized: "Couldn't save")
    }
  }
}

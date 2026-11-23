import SwiftUI
import ThoughtsCore

struct OfferChipView: View {
  enum Kind: Equatable {
    case clipboard
    case file
  }

  let kind: Kind
  let thumbnail: NSImage?
  let keycap: KeycapContent?

  var body: some View {
    ChipSurface {
      ChipSlot {
        if let thumbnail {
          ChipThumbnail(image: thumbnail)
        } else {
          Image(systemName: "photo")
            .font(.system(size: 18, weight: .light))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        }
      }
      ChipText(title: title, message: message)
      if let keycap {
        Keycap(content: keycap)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var title: LocalizedStringKey {
    switch kind {
    case .clipboard: "Image copied"
    case .file: "Screenshot saved"
    }
  }

  private var message: String {
    keycap == nil
      ? String(localized: "Click to keep") : String(localized: "Keep as a thought?")
  }
}

struct Keycap: View {
  @Environment(\.colorScheme) private var colorScheme

  let content: KeycapContent

  var body: some View {
    label
      .font(.system(size: 11, weight: .regular))
      .foregroundStyle(Color(nsColor: .secondaryLabelColor))
      .padding(.horizontal, 7)
      .frame(height: 22)
      .background(
        colorScheme == .dark ? Color(white: 0.227) : Color(white: 0.933),
        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
      )
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var label: some View {
    switch content {
    case .doubled(let modifier):
      HStack(spacing: 1) {
        Image(systemName: modifier.symbolName)
        Image(systemName: modifier.symbolName)
      }
    case .text(let text):
      Text(verbatim: text)
    }
  }
}

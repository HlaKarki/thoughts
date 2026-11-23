import ImageIO
import SwiftUI
import ThoughtsCore

extension Thought {
  var imageFileURL: URL? {
    guard case .image(let fileName, _) = content else { return nil }
    return file.deletingLastPathComponent().appendingPathComponent(fileName)
  }
}

enum PreviewImageLoader {
  static let maxPixel: CGFloat = 1400

  static func load(_ url: URL) async -> CGImage? {
    await Task.detached(priority: .userInitiated) { decode(url) }.value
  }

  static func decode(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixel,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }
}

struct PreviewHost: View {
  let list: ListModel
  @State private var image: CGImage?

  var body: some View {
    if let thought = list.previewThought {
      PreviewView(thought: thought, image: image)
        .task(id: thought.imageFileURL) {
          image = nil
          guard let url = thought.imageFileURL else { return }
          image = await PreviewImageLoader.load(url)
        }
    }
  }
}

struct PreviewView: View {
  let thought: Thought
  let image: CGImage?
  @Environment(\.colorScheme) private var colorScheme

  static let width: CGFloat = 620
  static let areaSize = CGSize(width: 596, height: 372)
  static let padding: CGFloat = 12
  static let labelWidth: CGFloat = 74

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      media
      VStack(alignment: .leading, spacing: 10) {
        if let note {
          Text(verbatim: note)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color(nsColor: .labelColor))
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 20, alignment: .leading)
        }
        VStack(alignment: .leading, spacing: 3) {
          ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
            HStack(alignment: .top, spacing: 0) {
              Text(detail.label)
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .frame(width: Self.labelWidth, alignment: .leading)
              Text(verbatim: detail.value)
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.disabled)
            }
            .font(.system(size: 12))
            .frame(minHeight: 17, alignment: .topLeading)
          }
        }
      }
      .padding(.horizontal, 6)
      .padding(.top, 18)
      HStack(spacing: 14) {
        if SourceOpener.canOpen(thought.source) {
          KeyHint(label: "Open original", key: "⌘O")
        }
        KeyHint(label: "Copy", key: "⌘C")
        KeyHint(label: "Close", key: "Space")
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.top, 10)
      .padding(.horizontal, 2)
    }
    .padding(Self.padding)
    .padding(.bottom, 2)
    .frame(width: Self.width)
    .background(
      colorScheme == .dark ? Color(white: 0.12) : Color.white,
      in: RoundedRectangle(cornerRadius: 16, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var media: some View {
    switch thought.content {
    case .text(let text):
      ScrollView {
        Text(verbatim: text)
          .font(.system(size: 15))
          .lineSpacing(3)
          .foregroundStyle(Color(nsColor: .labelColor))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
      }
      .frame(width: Self.areaSize.width)
      .frame(maxHeight: Self.areaSize.height)
      .fixedSize(horizontal: false, vertical: true)
      .background(
        Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    case .image:
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color.primary.opacity(0.04))
        if let image {
          Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
      }
      .frame(width: Self.areaSize.width, height: Self.areaSize.height)
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
      }
    }
  }

  private var note: String? {
    guard case .image(_, let note) = thought.content, !note.isEmpty else { return nil }
    return note
  }

  private struct Detail {
    let label: LocalizedStringKey
    let value: String
  }

  private var details: [Detail] {
    var rows: [Detail] = []
    if let from = Self.from(thought.source) {
      rows.append(Detail(label: "From", value: from))
    }
    rows.append(Detail(label: "Saved", value: Self.time(thought.created)))
    if let done = thought.done {
      rows.append(Detail(label: "Done", value: Self.time(done)))
    }
    let file = thought.imageFileURL ?? thought.file
    rows.append(Detail(label: "File", value: (file.path as NSString).abbreviatingWithTildeInPath))
    return rows
  }

  static func from(_ source: Source?) -> String? {
    guard let source else { return nil }
    let parts = [source.app, source.title ?? source.window]
      .compactMap { $0 }
      .filter { !$0.isEmpty }
    if !parts.isEmpty { return parts.joined(separator: ", ") }
    if let url = source.url { return url.absoluteString }
    if let file = source.file, !file.isEmpty {
      return (file as NSString).abbreviatingWithTildeInPath
    }
    return nil
  }

  static func time(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .short
    formatter.doesRelativeDateFormatting = true
    return formatter.string(from: date)
  }
}

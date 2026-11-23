import ImageIO
import SwiftUI

enum ThumbnailLoader {
  static let maxSize = CGSize(width: 164, height: 104)
  static let pixelScale: CGFloat = 2

  private final class Box {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
  }

  private nonisolated(unsafe) static let cache = NSCache<NSURL, Box>()

  static func cached(_ url: URL) -> CGImage? {
    cache.object(forKey: url as NSURL)?.image
  }

  static func load(_ url: URL) async -> CGImage? {
    if let image = cached(url) { return image }
    let image = await Task.detached(priority: .userInitiated) { decode(url) }.value
    if let image { cache.setObject(Box(image), forKey: url as NSURL) }
    return image
  }

  static func decode(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      var width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
      var height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
      width > 0, height > 0
    else { return nil }
    if let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue,
      (5...8).contains(orientation)
    {
      swap(&width, &height)
    }
    let fit = min(maxSize.width / width, maxSize.height / height, 1)
    let pixels = (max(width, height) * fit * pixelScale).rounded(.up)
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: pixels,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }
}

struct RowThumbnail: View {
  let url: URL
  @State private var image: CGImage?
  @State private var failed = false

  init(url: URL) {
    self.url = url
    _image = State(initialValue: ThumbnailLoader.cached(url))
  }

  var body: some View {
    content
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
      }
      .task(id: url) {
        guard image == nil else { return }
        image = await ThumbnailLoader.load(url)
        failed = image == nil
      }
  }

  private static func fitted(_ image: CGImage) -> CGSize {
    let width = CGFloat(image.width) / ThumbnailLoader.pixelScale
    let height = CGFloat(image.height) / ThumbnailLoader.pixelScale
    let fit = min(
      ThumbnailLoader.maxSize.width / width, ThumbnailLoader.maxSize.height / height, 1)
    return CGSize(width: width * fit, height: height * fit)
  }

  @ViewBuilder
  private var content: some View {
    if let image {
      Image(decorative: image, scale: ThumbnailLoader.pixelScale)
        .resizable()
        .frame(width: Self.fitted(image).width, height: Self.fitted(image).height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    } else {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.primary.opacity(0.06))
        .frame(width: ThumbnailLoader.maxSize.width, height: ThumbnailLoader.maxSize.height)
        .overlay {
          if failed {
            Image(systemName: "photo")
              .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
          }
        }
    }
  }
}

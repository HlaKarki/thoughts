import AppKit
import ImageIO

enum OfferThumbnail {
  static let side = 40
  static let scale = 2
  private static let reading = BlockingQueue("thoughts.offer-thumbnail.read", concurrent: true)

  static func make(file: URL) async -> NSImage? {
    await reading.run { image(from: CGImageSourceCreateWithURL(file as CFURL, nil)) }
  }

  static func make(data: Data) async -> NSImage? {
    await Task.detached { image(from: CGImageSourceCreateWithData(data as CFData, nil)) }.value
  }

  private static func image(from source: CGImageSource?) -> NSImage? {
    guard let source else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: side * scale,
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    return NSImage(
      cgImage: cgImage,
      size: NSSize(width: cgImage.width / scale, height: cgImage.height / scale))
  }
}

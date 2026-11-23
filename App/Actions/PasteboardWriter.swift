import AppKit

@MainActor
final class PasteboardWriter {
  private static let remembered = 64

  private let pasteboard: NSPasteboard
  private(set) var ownChangeCounts: Set<Int> = []
  var onOwnChange: (Int) -> Void = { _ in }

  init(pasteboard: NSPasteboard = .general) {
    self.pasteboard = pasteboard
  }

  func write(text: String) {
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    noteOwn(pasteboard.changeCount)
  }

  func write(imageAt url: URL) {
    pasteboard.clearContents()
    if let png = Self.pngData(at: url) {
      pasteboard.setData(png, forType: .png)
    }
    pasteboard.setString(url.absoluteString, forType: .fileURL)
    noteOwn(pasteboard.changeCount)
  }

  func noteOwn(_ changeCount: Int) {
    ownChangeCounts.insert(changeCount)
    if ownChangeCounts.count > Self.remembered, let oldest = ownChangeCounts.min() {
      ownChangeCounts.remove(oldest)
    }
    onOwnChange(changeCount)
  }

  private static let pngSignature = Data([0x89, 0x50, 0x4E, 0x47])

  private static func pngData(at url: URL) -> Data? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    if data.starts(with: pngSignature) { return data }
    return NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:])
  }
}

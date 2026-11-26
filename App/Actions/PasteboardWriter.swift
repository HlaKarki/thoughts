import AppKit

@MainActor
final class PasteboardWriter {
  private static let remembered = 64
  private static let reading = BlockingQueue("thoughts.copy.image-read", concurrent: true)

  private let pasteboard: NSPasteboard
  private let readImage: @Sendable (URL) -> ImageFile
  private(set) var ownChangeCounts: Set<Int> = []
  var onOwnChange: (Int) -> Void = { _ in }

  init(
    pasteboard: NSPasteboard = .general,
    readImage: @escaping @Sendable (URL) -> ImageFile = PasteboardWriter.readImage
  ) {
    self.pasteboard = pasteboard
    self.readImage = readImage
  }

  func write(text: String) {
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    noteOwn(pasteboard.changeCount)
  }

  enum ImageWrite: Equatable {
    case written
    case missing
    case unreadable
  }

  enum ImageFile: Sendable {
    case png(Data)
    case missing
    case unreadable
  }

  @discardableResult
  func write(imageAt url: URL) async -> ImageWrite {
    let readImage = readImage
    let png: Data
    switch await Self.reading.run({ readImage(url) }) {
    case .png(let data): png = data
    case .missing: return .missing
    case .unreadable: return .unreadable
    }
    pasteboard.clearContents()
    pasteboard.setData(png, forType: .png)
    pasteboard.setString(url.absoluteString, forType: .fileURL)
    noteOwn(pasteboard.changeCount)
    return .written
  }

  func noteOwn(_ changeCount: Int) {
    ownChangeCounts.insert(changeCount)
    if ownChangeCounts.count > Self.remembered, let oldest = ownChangeCounts.min() {
      ownChangeCounts.remove(oldest)
    }
    onOwnChange(changeCount)
  }

  nonisolated private static let pngSignature = Data([0x89, 0x50, 0x4E, 0x47])

  nonisolated static func readImage(at url: URL) -> ImageFile {
    guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
    guard let data = try? Data(contentsOf: url) else { return .unreadable }
    if data.starts(with: pngSignature) { return .png(data) }
    guard let png = NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:])
    else { return .unreadable }
    return .png(png)
  }
}

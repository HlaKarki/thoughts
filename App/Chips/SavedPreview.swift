import AppKit
import ThoughtsCore

struct SavedPreview: Equatable {
  static let characterLimit = 200

  let line: String?
  let thumbnail: NSImage?

  static var withoutThought: SavedPreview {
    SavedPreview(line: String(localized: "It is already in your thoughts"), thumbnail: nil)
  }

  init(line: String?, thumbnail: NSImage?) {
    self.line = line
    self.thumbnail = thumbnail
  }

  init(thought: Thought, thumbnail: NSImage?) {
    switch thought.content {
    case .text(let text):
      self.init(line: Self.start(of: text), thumbnail: nil)
    case .image(_, let note):
      self.init(
        line: Self.firstLine(of: note) ?? Self.origin(of: thought.source), thumbnail: thumbnail)
    }
  }

  static func load(_ thought: Thought) async -> SavedPreview {
    guard case .image = thought.content,
      let file = ThoughtStore(folder: thought.file.deletingLastPathComponent()).imageURL(
        of: thought)
    else { return SavedPreview(thought: thought, thumbnail: nil) }
    return SavedPreview(thought: thought, thumbnail: await OfferThumbnail.make(file: file))
  }

  private static func start(of text: String) -> String? {
    let words = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return clipped(words)
  }

  private static func firstLine(of note: String) -> String? {
    let line = note.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .first { !$0.isEmpty }
    return line.flatMap(clipped)
  }

  private static func origin(of source: Source?) -> String? {
    if let path = source?.file, !path.isEmpty {
      return URL(fileURLWithPath: path).lastPathComponent
    }
    guard let app = source?.app, !app.isEmpty else { return nil }
    return app
  }

  private static func clipped(_ line: String) -> String? {
    line.isEmpty ? nil : String(line.prefix(characterLimit))
  }
}

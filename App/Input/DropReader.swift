import AppKit
import ThoughtsCore
import UniformTypeIdentifiers

enum DropReader {
  static func thoughts(from pasteboard: NSPasteboard, source: Source?, now: Date) -> [NewThought] {
    let files =
      (pasteboard.readObjects(
        forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    if !files.isEmpty {
      return files.map { NewThought.fromFile($0, source: source, created: now) }
    }
    for type in [UTType.png, .tiff] {
      if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(type.identifier)) {
        return [
          NewThought(content: .image(.data(data, type), note: ""), source: source, created: now)
        ]
      }
    }
    if let text = pasteboard.string(forType: .string) {
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        return [NewThought(content: .text(trimmed), source: source, created: now)]
      }
    }
    return []
  }
}

import AppKit
import ThoughtsCore
import UniformTypeIdentifiers

enum PasteContent {
  case image(ImageInput, preview: NSImage)
  case imageFiles([URL])
  case text(String)
  case nothing
}

enum PasteboardReader {
  static func fileURLs(in pasteboard: NSPasteboard) -> [URL] {
    (pasteboard.readObjects(
      forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
  }

  static func imageData(in pasteboard: NSPasteboard) -> (data: Data, type: UTType)? {
    for type in [UTType.png, .tiff] {
      if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(type.identifier)) {
        return (data, type)
      }
    }
    return nil
  }

  static func paste(from pasteboard: NSPasteboard) -> PasteContent {
    let files = fileURLs(in: pasteboard)
    let images = files.filter {
      UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true
    }
    if !images.isEmpty { return .imageFiles(images) }
    let text = pasteboard.string(forType: .string).flatMap { $0.isEmpty ? nil : $0 }
    let image = files.isEmpty ? imageData(in: pasteboard) : nil
    let picture = image.flatMap { found in
      NSImage(data: found.data).map {
        PasteContent.image(.data(found.data, found.type), preview: $0)
      }
    }
    if let text {
      if isSingleURL(text), let picture { return picture }
      return .text(text)
    }
    return picture ?? .nothing
  }

  nonisolated static func preview(of files: [URL]) -> (file: URL, preview: NSImage)? {
    for file in files {
      if let preview = NSImage(contentsOf: file) { return (file, preview) }
    }
    return nil
  }

  static func isSingleURL(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace),
      let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https", url.host != nil
    else { return false }
    return true
  }
}

enum DropReader {
  static func thoughts(from pasteboard: NSPasteboard, source: Source?, now: Date) -> [NewThought] {
    let files = PasteboardReader.fileURLs(in: pasteboard)
    if !files.isEmpty {
      return files.map { NewThought.fromFile($0, source: source, created: now) }
    }
    if let found = PasteboardReader.imageData(in: pasteboard) {
      return [
        NewThought(
          content: .image(.data(found.data, found.type), note: ""), source: source, created: now)
      ]
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

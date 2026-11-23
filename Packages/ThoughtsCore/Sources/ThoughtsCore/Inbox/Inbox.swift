import Foundation
import UniformTypeIdentifiers

public struct Inbox: Sendable {
  static let itemFile = "item.json"
  public static let failedFolder = "Failed"

  public let folder: URL

  public init(folder: URL) {
    self.folder = folder
  }

  public func write(_ item: InboxItem, attachment: URL?) throws -> URL {
    let manager = FileManager.default
    let name = Self.entryName(created: item.created)
    let staging = folder.appendingPathComponent(".\(name)", isDirectory: true)
    let entry = folder.appendingPathComponent(name, isDirectory: true)
    do {
      try manager.createDirectory(at: staging, withIntermediateDirectories: true)
      var stored = item
      if let attachment {
        let fileName = Self.attachmentName(attachment)
        try manager.copyItem(at: attachment, to: staging.appendingPathComponent(fileName))
        stored.fileName = fileName
      }
      let data = try JSONEncoder().encode(stored)
      try data.write(to: staging.appendingPathComponent(Self.itemFile))
      try manager.moveItem(at: staging, to: entry)
    } catch {
      try? manager.removeItem(at: staging)
      throw ThoughtsError.io(error.localizedDescription)
    }
    return entry
  }

  public func pending() throws -> [URL] {
    let manager = FileManager.default
    guard manager.fileExists(atPath: folder.path) else { return [] }
    let names: [String]
    do {
      names = try manager.contentsOfDirectory(atPath: folder.path)
    } catch {
      throw ThoughtsError.io(error.localizedDescription)
    }
    return names.filter { !$0.hasPrefix(".") && $0 != Self.failedFolder }.sorted()
      .map { folder.appendingPathComponent($0, isDirectory: true) }
      .filter { Self.isDirectory($0) }
  }

  public func newThought(from entry: URL, source: Source?) throws -> NewThought {
    let item = try read(entry)
    let recorded = item.sourceApp ?? source
    switch item.kind {
    case .text:
      let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard !text.isEmpty else { throw ThoughtsError.io("The shared item has no text") }
      return NewThought(content: .text(text), source: recorded, created: item.created)
    case .url:
      guard let url = item.url else { throw ThoughtsError.io("The shared item has no link") }
      var linked = recorded ?? Source()
      linked.url = url
      linked.title = item.title
      return NewThought(content: .text(url.absoluteString), source: linked, created: item.created)
    case .file:
      if let fileName = item.fileName, Self.isImage(fileName) {
        var new = NewThought.fromFile(
          entry.appendingPathComponent(fileName), source: recorded, created: item.created)
        new.source?.file = item.originalPath
        if new.source == Source() { new.source = nil }
        return new
      }
      guard let path = item.originalPath else {
        throw ThoughtsError.io("The shared item has no file")
      }
      return NewThought.fromFile(
        URL(fileURLWithPath: path), source: recorded, created: item.created)
    }
  }

  public func remove(_ entry: URL) throws {
    do {
      try FileManager.default.removeItem(at: entry)
    } catch {
      throw ThoughtsError.io(error.localizedDescription)
    }
  }

  public func isReadable(_ entry: URL) -> Bool {
    (try? read(entry)) != nil
  }

  public func quarantine(_ entry: URL) throws {
    let manager = FileManager.default
    let failed = folder.appendingPathComponent(Self.failedFolder, isDirectory: true)
    do {
      try manager.createDirectory(at: failed, withIntermediateDirectories: true)
      try manager.moveItem(at: entry, to: failed.appendingPathComponent(entry.lastPathComponent))
    } catch {
      throw ThoughtsError.io(error.localizedDescription)
    }
  }

  private func read(_ entry: URL) throws -> InboxItem {
    do {
      let data = try Data(contentsOf: entry.appendingPathComponent(Self.itemFile))
      return try JSONDecoder().decode(InboxItem.self, from: data)
    } catch {
      throw ThoughtsError.io(error.localizedDescription)
    }
  }

  private static func entryName(created: Date) -> String {
    let millis = Int64((created.timeIntervalSince1970 * 1000).rounded(.down))
    return "\(millis)-\(UUID().uuidString)"
  }

  private static func attachmentName(_ attachment: URL) -> String {
    let name = attachment.lastPathComponent
    return name == itemFile ? "attachment-\(name)" : name
  }

  private static func isImage(_ fileName: String) -> Bool {
    let ext = (fileName as NSString).pathExtension
    return UTType(filenameExtension: ext)?.conforms(to: .image) == true
  }

  private static func isDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }
}

import Foundation

public struct ThoughtStore: Sendable {
  public let folder: URL
  private let trash: @Sendable (URL) throws -> Void

  public init(
    folder: URL,
    trash: @escaping @Sendable (URL) throws -> Void = ThoughtStore.moveToTrash
  ) {
    self.folder = folder
    self.trash = trash
  }

  public static func moveToTrash(_ url: URL) throws {
    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
  }

  public func add(_ new: NewThought) throws -> Thought {
    try requireFolder()
    let id = ThoughtID.random()
    let created = FrontMatterCodec.canonical(new.created)
    let base = FileNaming.baseName(created: created, id: id)
    let file = folder.appendingPathComponent(base + ".md")

    var imageURL: URL?
    let content: ThoughtContent
    switch new.content {
    case .text(let text):
      content = .text(text)
    case .image(let input, let note):
      let name = try wrapped { try ImageWriter.write(input, base: base, in: folder) }
      imageURL = folder.appendingPathComponent(name)
      content = .image(fileName: name, note: note)
    }

    var thought = Thought(
      id: id,
      created: created,
      content: content,
      source: new.source,
      file: file,
      version: FileVersion(modified: .distantPast, size: 0)
    )
    do {
      thought.version = try wrapped {
        try AtomicFile.write(
          Data(FrontMatterCodec.encode(thought).utf8), to: file, target: .new)
      }
    } catch {
      if let imageURL { try? FileManager.default.removeItem(at: imageURL) }
      throw error
    }
    return thought
  }

  public func entries() throws -> [ThoughtEntry] {
    let keyed = try markdownFiles().map { file -> (entry: ThoughtEntry, date: Date) in
      let entry = try entry(at: file)
      switch entry {
      case .thought(let thought):
        return (entry, thought.created)
      case .malformed:
        return (entry, (try? AtomicFile.info(at: file).birth) ?? .distantPast)
      }
    }
    return keyed.sorted { lhs, rhs in
      if lhs.date != rhs.date { return lhs.date < rhs.date }
      return fileName(of: lhs.entry) < fileName(of: rhs.entry)
    }.map(\.entry)
  }

  public func entry(at file: URL) throws -> ThoughtEntry {
    let info: DiskInfo
    let data: Data
    do {
      info = try AtomicFile.info(at: file)
      data = try Data(contentsOf: file)
    } catch AtomicFileError.missing {
      throw ThoughtsError.notFound(file.lastPathComponent)
    } catch {
      throw mapped(error)
    }
    guard var text = String(data: data, encoding: .utf8) else {
      return .malformed(file: file, reason: "File is not valid UTF-8 text")
    }
    if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
    return FrontMatterCodec.decode(
      text,
      file: file,
      version: info.version,
      fallbackCreated: FrontMatterCodec.canonical(info.birth)
    )
  }

  public func thought(matching idOrPrefix: String) throws -> Thought {
    let thoughts = try entries().compactMap { entry -> Thought? in
      if case .thought(let thought) = entry { return thought }
      return nil
    }
    if let exact = thoughts.first(where: { $0.id.rawValue == idOrPrefix }) {
      return exact
    }
    let matches =
      idOrPrefix.count >= 4 ? thoughts.filter { $0.id.rawValue.hasPrefix(idOrPrefix) } : []
    switch matches.count {
    case 0: throw ThoughtsError.notFound(idOrPrefix)
    case 1: return matches[0]
    default: throw ThoughtsError.ambiguous(idOrPrefix, matches.map(\.id))
    }
  }

  public func setText(_ text: String, of id: ThoughtID, expected: FileVersion) throws -> Thought {
    var thought = try require(id, missing: .deletedOnDisk(id))
    guard thought.version == expected else { throw ThoughtsError.changedOnDisk(id) }
    switch thought.content {
    case .text:
      thought.content = .text(text)
    case .image(let fileName, _):
      thought.content = .image(fileName: fileName, note: text)
    }
    return try rewrite(thought)
  }

  public func setDone(_ done: Bool, for id: ThoughtID, at date: Date) throws -> Thought {
    var thought = try require(id, missing: .notFound(id.rawValue))
    thought.done = done ? date : nil
    if !done { thought.cleared = false }
    return try rewrite(thought)
  }

  public func clearDone() throws -> [ThoughtID] {
    var cleared: [ThoughtID] = []
    for case .thought(var thought) in try entries() where thought.done != nil && !thought.cleared {
      thought.cleared = true
      _ = try rewrite(thought)
      cleared.append(thought.id)
    }
    return cleared
  }

  public func delete(_ ids: [ThoughtID]) throws {
    for id in ids {
      guard case .found(let thought) = try locate(id) else { continue }
      try wrapped { try trash(thought.file) }
      if let image = imageURL(of: thought), FileManager.default.fileExists(atPath: image.path) {
        try wrapped { try trash(image) }
      }
    }
  }

  public func imageURL(of thought: Thought) -> URL? {
    guard case .image(let fileName, _) = thought.content else { return nil }
    return thought.file.deletingLastPathComponent().appendingPathComponent(fileName)
  }
}

extension ThoughtStore {
  private enum Located {
    case found(Thought)
    case malformed
    case missing
  }

  private func requireFolder() throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else { throw ThoughtsError.storageUnavailable(folder.path) }
  }

  private func markdownFiles() throws -> [URL] {
    try requireFolder()
    let names: [String]
    do {
      names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
    } catch {
      throw ThoughtsError.storageUnavailable(folder.path)
    }
    return
      names
      .filter { !$0.hasPrefix(".") && ($0 as NSString).pathExtension.lowercased() == "md" }
      .sorted()
      .map { folder.appendingPathComponent($0) }
      .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true }
  }

  private func fileName(of entry: ThoughtEntry) -> String {
    switch entry {
    case .thought(let thought): thought.file.lastPathComponent
    case .malformed(let file, _): file.lastPathComponent
    }
  }

  private func locate(_ id: ThoughtID) throws -> Located {
    let files = try markdownFiles()
    let suffix = "-" + id.rawValue
    func likely(_ file: URL) -> Bool {
      let stem = file.deletingPathExtension().lastPathComponent
      return stem == id.rawValue || stem.hasSuffix(suffix)
    }
    var sawMalformed = false
    for file in files where likely(file) {
      switch try entry(at: file) {
      case .thought(let thought) where thought.id == id: return .found(thought)
      case .malformed: sawMalformed = true
      default: continue
      }
    }
    for file in files where !likely(file) {
      if case .thought(let thought) = try entry(at: file), thought.id == id {
        return .found(thought)
      }
    }
    return sawMalformed ? .malformed : .missing
  }

  private func require(_ id: ThoughtID, missing: ThoughtsError) throws -> Thought {
    switch try locate(id) {
    case .found(let thought): return thought
    case .malformed: throw ThoughtsError.changedOnDisk(id)
    case .missing: throw missing
    }
  }

  private func rewrite(_ thought: Thought) throws -> Thought {
    var updated = thought
    updated.created = FrontMatterCodec.canonical(thought.created)
    updated.done = thought.done.map(FrontMatterCodec.canonical)
    let data = Data(FrontMatterCodec.encode(updated).utf8)
    do {
      updated.version = try AtomicFile.write(
        data, to: thought.file, target: .replacing(thought.version))
    } catch AtomicFileError.changed {
      throw ThoughtsError.changedOnDisk(thought.id)
    } catch AtomicFileError.missing {
      throw ThoughtsError.deletedOnDisk(thought.id)
    } catch {
      throw mapped(error)
    }
    return updated
  }

  private func wrapped<T>(_ body: () throws -> T) throws -> T {
    do {
      return try body()
    } catch {
      throw mapped(error)
    }
  }

  private func mapped(_ error: Error) -> ThoughtsError {
    switch error {
    case let error as ThoughtsError: error
    case AtomicFileError.exists: .io("A file with that name already exists")
    case AtomicFileError.changed: .io("The file changed while it was being written")
    case AtomicFileError.missing: .io("The file is missing")
    default: .io(error.localizedDescription)
    }
  }
}

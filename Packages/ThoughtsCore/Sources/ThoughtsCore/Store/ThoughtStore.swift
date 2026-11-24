import Foundation

public struct ThoughtStore: Sendable {
  public let folder: URL
  private let trash: @Sendable (URL) throws -> URL

  public init(
    folder: URL,
    trash: @escaping @Sendable (URL) throws -> URL = ThoughtStore.moveToTrash
  ) {
    self.folder = folder
    self.trash = trash
  }

  public static func moveToTrash(_ url: URL) throws -> URL {
    var landed: NSURL?
    try FileManager.default.trashItem(at: url, resultingItemURL: &landed)
    return (landed as URL?) ?? url
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
    try scan().map { entry -> (entry: ThoughtEntry, date: Date) in
      switch entry {
      case .thought(let thought):
        return (entry, thought.created)
      case .malformed(let file, _):
        return (entry, (try? AtomicFile.info(at: file).birth) ?? .distantPast)
      }
    }
    .sorted { lhs, rhs in
      if lhs.date != rhs.date { return lhs.date < rhs.date }
      return fileName(of: lhs.entry) < fileName(of: rhs.entry)
    }
    .map(\.entry)
  }

  public func entry(at file: URL) throws -> ThoughtEntry {
    do {
      return try load(file)
    } catch AtomicFileError.missing {
      throw ThoughtsError.notFound(file.lastPathComponent)
    } catch {
      throw mapped(error)
    }
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
    try clearingDone().map(\.id)
  }

  public func clearingDone() throws -> [Thought] {
    var cleared: [Thought] = []
    try clearingDone(landing: &cleared)
    return cleared
  }

  public func clearingDone(landing cleared: inout [Thought]) throws {
    for case .thought(var thought) in try entries() where thought.done != nil && !thought.cleared {
      thought.cleared = true
      cleared.append(try rewrite(thought))
    }
  }

  @discardableResult
  public func delete(_ ids: [ThoughtID]) throws -> [TrashedFile] {
    var moved: [TrashedFile] = []
    try delete(ids, landing: &moved)
    return moved
  }

  public func delete(_ ids: [ThoughtID], landing moved: inout [TrashedFile]) throws {
    for id in ids {
      guard case .found(let thought) = try locate(id) else { continue }
      moved.append(try trashed(thought.file))
      if let image = ownImageURL(of: thought), FileManager.default.fileExists(atPath: image.path) {
        moved.append(try trashed(image))
      }
    }
  }

  public func trashFiles(_ originals: [URL]) throws -> [TrashedFile] {
    try requireFolder()
    for original in originals where !FileManager.default.fileExists(atPath: original.path) {
      throw RestoreError.changed
    }
    var moved: [TrashedFile] = []
    do {
      for original in originals {
        moved.append(try trashed(original))
      }
    } catch {
      try? restore(moved)
      throw error
    }
    return moved
  }

  public func restore(_ files: [TrashedFile]) throws {
    try requireFolder()
    let manager = FileManager.default
    for file in files where !manager.fileExists(atPath: file.trashed.path) {
      throw RestoreError.notInTrash
    }
    for file in files where manager.fileExists(atPath: file.original.path) {
      throw RestoreError.nameTaken
    }
    var restored: [TrashedFile] = []
    for file in files {
      do {
        try manager.moveItem(at: file.trashed, to: file.original)
        restored.append(file)
      } catch {
        for done in restored.reversed() {
          try? manager.moveItem(at: done.original, to: done.trashed)
        }
        throw mapped(error)
      }
    }
  }

  public func amend(_ amendments: [Amendment]) throws -> [Thought] {
    var originals: [Thought] = []
    for amendment in amendments {
      originals.append(try current(for: amendment))
    }
    var applied: [Thought] = []
    for (amendment, original) in zip(amendments, originals) {
      var thought = original
      switch amendment.change {
      case .mark(let mark):
        thought.done = mark.done
        thought.cleared = mark.cleared
      case .text(let text):
        switch thought.content {
        case .text: thought.content = .text(text)
        case .image(let fileName, _): thought.content = .image(fileName: fileName, note: text)
        }
      }
      do {
        applied.append(try rewrite(thought))
      } catch {
        for (back, written) in zip(originals, applied).reversed() {
          var undone = back
          undone.version = written.version
          _ = try? rewrite(undone)
        }
        throw error
      }
    }
    return applied
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

  func markdownFiles() throws -> [URL] {
    try markdownNames().map { folder.appendingPathComponent($0) }
  }

  func markdownNames() throws -> [String] {
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
      .filter { !Self.isDirectory(folder.appendingPathComponent($0)) }
  }

  static func isDirectory(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
  }

  private func fileName(of entry: ThoughtEntry) -> String {
    switch entry {
    case .thought(let thought): thought.file.lastPathComponent
    case .malformed(let file, _): file.lastPathComponent
    }
  }

  private func load(_ file: URL) throws -> ThoughtEntry {
    let info = try AtomicFile.info(at: file)
    let data: Data
    do {
      data = try Data(contentsOf: file)
    } catch {
      do {
        _ = try AtomicFile.info(at: file)
      } catch AtomicFileError.missing {
        throw AtomicFileError.missing
      } catch {}
      throw error
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

  private func scan() throws -> [ThoughtEntry] {
    var loaded: [ThoughtEntry] = []
    for file in try markdownFiles() {
      do {
        loaded.append(try load(file))
      } catch AtomicFileError.missing {
        continue
      } catch {
        loaded.append(.malformed(file: file, reason: "File could not be read: \(describe(error))"))
      }
    }
    return resolvingDuplicateIDs(loaded)
  }

  private func resolvingDuplicateIDs(_ loaded: [ThoughtEntry]) -> [ThoughtEntry] {
    let items = loaded.compactMap { entry -> (id: ThoughtID, name: String)? in
      guard case .thought(let thought) = entry else { return nil }
      return (thought.id, thought.file.lastPathComponent)
    }
    let demoted = DuplicateIDs.demotions(items)
    return loaded.map { entry in
      if case .thought(let thought) = entry, let reason = demoted[thought.file.lastPathComponent] {
        return .malformed(file: thought.file, reason: reason)
      }
      return entry
    }
  }

  private func trashed(_ url: URL) throws -> TrashedFile {
    let landed = try wrapped { try trash(url) }
    return TrashedFile(original: url, trashed: landed)
  }

  private func current(for amendment: Amendment) throws -> Thought {
    let entry: ThoughtEntry
    do {
      entry = try load(amendment.file)
    } catch AtomicFileError.missing {
      throw ThoughtsError.deletedOnDisk(amendment.id)
    } catch {
      throw mapped(error)
    }
    guard case .thought(let thought) = entry, thought.id == amendment.id,
      thought.version == amendment.expected
    else { throw ThoughtsError.changedOnDisk(amendment.id) }
    return thought
  }

  private func ownImageURL(of thought: Thought) -> URL? {
    guard let image = imageURL(of: thought),
      image.lastPathComponent != thought.file.lastPathComponent
    else { return nil }
    let imageBase = image.deletingPathExtension().lastPathComponent
    return imageBase == thought.file.deletingPathExtension().lastPathComponent ? image : nil
  }

  private func describe(_ error: Error) -> String {
    if case ThoughtsError.io(let message) = error { return message }
    return error.localizedDescription
  }

  private func locate(_ id: ThoughtID) throws -> Located {
    let loaded = try scan()
    var sawMalformed = false
    for entry in loaded {
      switch entry {
      case .thought(let thought) where thought.id == id: return .found(thought)
      case .malformed(let file, _) where DuplicateIDs.owns(file.lastPathComponent, id):
        sawMalformed = true
      default: continue
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

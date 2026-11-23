import Foundation

public struct IndexSync: Sendable {
  private let store: ThoughtStore
  private let index: SearchIndex
  private let recognizer: (any TextRecognizing)?

  public init(store: ThoughtStore, index: SearchIndex, recognizer: (any TextRecognizing)?) {
    self.store = store
    self.index = index
    self.recognizer = recognizer
  }

  public func reconcile(_ files: [URL]?) throws -> IndexChanges {
    try run(files, rereadAll: false)
  }

  public func rebuild() throws -> IndexChanges {
    try run(nil, rereadAll: true)
  }

  private func run(_ files: [URL]?, rereadAll: Bool) throws -> IndexChanges {
    let known = try index.states()
    var removed: [String] = []
    let names: [String]
    if let files {
      names = Set(files.map(\.lastPathComponent).filter(Self.isMarkdownName)).sorted()
    } else {
      names = try store.markdownFiles().map(\.lastPathComponent)
      removed = Set(known.keys).subtracting(names).sorted()
    }

    var loaded: [IndexRow] = []
    for name in names {
      let url = store.folder.appendingPathComponent(name)
      let disk: DiskInfo?
      do {
        disk = try AtomicFile.info(at: url)
      } catch AtomicFileError.missing {
        if known[name] != nil { removed.append(name) }
        continue
      } catch {
        disk = nil
      }
      if !rereadAll, let disk, let state = known[name], !needsWork(state, disk: disk) { continue }
      if let row = try load(name, url: url, disk: disk, state: known[name]) {
        loaded.append(row)
      } else if known[name] != nil {
        removed.append(name)
      }
    }

    let rows = recognize(loaded)
    let demoted = rows.isEmpty && removed.isEmpty ? [] : try index.apply(rows, removing: removed)

    var changes = IndexChanges(removed: removed.sorted())
    for row in rows {
      if known[row.name] == nil {
        changes.added.append(row.name)
      } else {
        changes.updated.append(row.name)
      }
    }
    let touched = Set(rows.map(\.name))
    changes.updated.append(contentsOf: demoted.filter { !touched.contains($0) })
    changes.added.sort()
    changes.updated.sort()
    return changes
  }

  private static let unknownVersion = FileVersion(modified: .distantPast, size: -1)

  private static func isMarkdownName(_ name: String) -> Bool {
    !name.hasPrefix(".") && (name as NSString).pathExtension.lowercased() == "md"
  }

  private func needsWork(_ state: IndexState, disk: DiskInfo) -> Bool {
    guard state.version == disk.version else { return true }
    guard let image = state.image else { return false }
    let current = imageVersion(named: image.name)
    if current != image.version { return true }
    return recognizer != nil && current != nil && state.recognized == nil
  }

  private func imageVersion(named name: String) -> FileVersion? {
    try? AtomicFile.info(at: store.folder.appendingPathComponent(name)).version
  }

  private func load(_ name: String, url: URL, disk: DiskInfo?, state: IndexState?) throws
    -> IndexRow?
  {
    let entry: ThoughtEntry
    do {
      entry = try store.entry(at: url)
    } catch ThoughtsError.notFound {
      return nil
    } catch ThoughtsError.io(let message) {
      entry = .malformed(file: url, reason: "File could not be read: \(message)")
    }
    var row = IndexRow(
      name: name,
      entry: entry,
      version: disk?.version ?? Self.unknownVersion,
      created: disk?.birth ?? .distantPast,
      birth: disk?.birth ?? .distantPast,
      image: nil,
      recognized: nil
    )
    if case .thought(let thought) = entry {
      row.created = thought.created
      if disk == nil { row.version = thought.version }
      if let imageURL = store.imageURL(of: thought) {
        let image = IndexedImage(
          name: imageURL.lastPathComponent,
          version: imageVersion(named: imageURL.lastPathComponent))
        row.image = image
        if let state, state.image == image { row.recognized = state.recognized }
      }
    }
    return row
  }

  private func recognize(_ rows: [IndexRow]) -> [IndexRow] {
    guard let recognizer else { return rows }
    return rows.map { row in
      guard let image = row.image, image.version != nil, row.recognized == nil else { return row }
      var row = row
      row.recognized = try? recognizer.text(in: store.folder.appendingPathComponent(image.name))
      return row
    }
  }
}

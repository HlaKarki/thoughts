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

    var rows: [IndexRow] = []
    for name in names {
      let url = store.folder.appendingPathComponent(name)
      let disk: DiskInfo?
      do {
        disk = try AtomicFile.info(at: url)
      } catch AtomicFileError.missing {
        removed.append(name)
        continue
      } catch {
        disk = nil
      }
      if !rereadAll, let disk, let state = known[name], !needsWork(state, disk: disk) { continue }
      if let row = try load(name, url: url, disk: disk, state: known[name], rereadAll: rereadAll) {
        rows.append(row)
      } else {
        removed.append(name)
      }
    }

    let write =
      rows.isEmpty && removed.isEmpty ? IndexWrite() : try index.apply(rows, removing: removed)
    var changes = IndexChanges(added: write.added, updated: write.updated, removed: write.removed)
    for name in write.demoted where !changes.touches(name) { changes.updated.append(name) }
    try recognizeBatches(of: rows, into: &changes)
    changes.added.sort()
    changes.updated.sort()
    changes.removed.sort()
    return changes
  }

  private static let unknownVersion = FileVersion(modified: .distantPast, size: -1)

  static func isMarkdownName(_ name: String) -> Bool {
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

  private func load(
    _ name: String, url: URL, disk: DiskInfo?, state: IndexState?, rereadAll: Bool
  ) throws -> IndexRow? {
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
        if let state, state.image == image, let text = state.recognized,
          !(rereadAll && text.isEmpty)
        {
          row.recognized = text
        }
      }
    }
    return row
  }

  private static let batchSize = 8

  private func recognizeBatches(of rows: [IndexRow], into changes: inout IndexChanges) throws {
    guard let recognizer else { return }
    let pending = rows.filter { $0.recognized == nil && $0.image?.version != nil }
    for start in stride(from: 0, to: pending.count, by: Self.batchSize) {
      let items = pending[start..<min(start + Self.batchSize, pending.count)].compactMap {
        row -> RecognizedImage? in
        guard let image = row.image else { return nil }
        let url = store.folder.appendingPathComponent(image.name)
        return RecognizedImage(
          name: row.name, image: image, text: (try? recognizer.text(in: url)) ?? "")
      }
      let write = try index.applyRecognized(items)
      for name in write.updated where !changes.touches(name) { changes.updated.append(name) }
      for name in write.removed {
        changes.added.removeAll { $0 == name }
        changes.updated.removeAll { $0 == name }
        if !changes.removed.contains(name) { changes.removed.append(name) }
      }
    }
  }
}

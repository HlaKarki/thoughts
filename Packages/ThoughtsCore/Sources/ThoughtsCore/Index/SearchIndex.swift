import Foundation
import GRDB
import Synchronization

struct ExactName: Hashable {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  static func == (lhs: ExactName, rhs: ExactName) -> Bool {
    lhs.value.utf8.elementsEqual(rhs.value.utf8)
  }

  func hash(into hasher: inout Hasher) {
    for byte in value.utf8 { hasher.combine(byte) }
  }
}

struct IndexedImage: Equatable {
  var name: String
  var version: FileVersion?
}

struct IndexRow {
  var name: String
  var entry: ThoughtEntry
  var version: FileVersion
  var created: Date
  var birth: Date
  var image: IndexedImage?
  var recognized: String?
}

struct IndexState: Equatable {
  var version: FileVersion
  var image: IndexedImage?
  var recognized: String?
}

public final class SearchIndex: Sendable {
  static let schemaVersion = 1

  private let pool: DatabasePool
  private let folder: Mutex<URL>

  public init(url: URL, folder: URL) throws {
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch {
      throw ThoughtsError.io("The search index folder could not be created")
    }
    pool = try Self.wrapped { try Self.openPool(url) }
    self.folder = Mutex(folder)
    try Self.wrapped { try Self.prepare(pool, folder: folder) }
  }

  public func entries(includeCleared: Bool) throws -> [ThoughtEntry] {
    let folder = folder.withLock { $0 }
    let rows = try Self.wrapped {
      try pool.read {
        try Row.fetchAll(
          $0,
          sql: """
            SELECT file, modified, size, entry, demotion FROM thoughts
            ORDER BY CASE WHEN malformed = 1 OR demotion IS NOT NULL THEN birth ELSE created END,
              file
            """)
      }
    }
    return rows.compactMap { row -> ThoughtEntry? in
      let url = folder.appendingPathComponent(row["file"] as String)
      if let reason = row["demotion"] as String? { return .malformed(file: url, reason: reason) }
      let version = FileVersion(
        modified: Date(timeIntervalSinceReferenceDate: row["modified"]), size: row["size"])
      let entry = StoredEntry.decode(row["entry"], file: url, version: version)
      if !includeCleared, case .thought(let thought) = entry, thought.cleared { return nil }
      return entry
    }
  }

  public func search(_ query: String) throws -> [ThoughtID] {
    guard let pattern = Self.pattern(for: query) else { return [] }
    let ids = try Self.wrapped {
      try pool.read {
        try String.fetchAll(
          $0,
          sql: """
            SELECT thoughts.id FROM thoughts_fts
            JOIN thoughts ON thoughts.seq = thoughts_fts.rowid
            WHERE thoughts_fts MATCH ? AND thoughts.malformed = 0 AND thoughts.demotion IS NULL
            ORDER BY thoughts.created, thoughts.file
            """,
          arguments: [pattern])
      }
    }
    return ids.compactMap { ThoughtID(rawValue: $0) }
  }

  public func imageTextExcerpts(for ids: [ThoughtID], query: String) throws -> [ThoughtID: String] {
    guard !ids.isEmpty, let pattern = Self.pattern(for: query) else { return [:] }
    let wanted = Set(ids.map(\.rawValue))
    let rows = try Self.wrapped {
      try pool.read {
        try Row.fetchAll(
          $0,
          sql: """
            SELECT thoughts.id AS id,
              snippet(thoughts_fts, 2, char(1), char(2), '…', 12) AS excerpt
            FROM thoughts_fts
            JOIN thoughts ON thoughts.seq = thoughts_fts.rowid
            WHERE thoughts_fts MATCH ? AND thoughts.recognized IS NOT NULL
            """,
          arguments: [pattern])
      }
    }
    var found: [ThoughtID: String] = [:]
    for row in rows {
      guard let id = ThoughtID(rawValue: row["id"]), wanted.contains(id.rawValue),
        let raw: String = row["excerpt"], raw.contains("\u{1}")
      else { continue }
      found[id] = raw.replacingOccurrences(of: "\u{1}", with: "")
        .replacingOccurrences(of: "\u{2}", with: "")
        .split(whereSeparator: \.isNewline).joined(separator: " ")
    }
    return found
  }

  private static func pattern(for query: String) -> String? {
    let words = query.split(whereSeparator: \.isWhitespace)
      .filter { $0.contains { $0.isLetter || $0.isNumber } }
    guard !words.isEmpty else { return nil }
    return
      words
      .map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"*" }
      .joined(separator: " AND ")
  }

  public func close() throws {
    try Self.wrapped { try pool.close() }
  }

  public func relocate(to folder: URL) throws {
    try Self.wrapped {
      try pool.writeWithoutTransaction { db in
        try db.inTransaction(.immediate) {
          try db.execute(
            sql: "UPDATE meta SET folder = ?", arguments: [Self.path(of: folder)])
          return .commit
        }
      }
    }
    self.folder.withLock { $0 = folder }
  }
}

extension SearchIndex {
  func states() throws -> [ExactName: IndexState] {
    let rows = try Self.wrapped {
      try pool.read {
        try Row.fetchAll(
          $0,
          sql: """
            SELECT file, modified, size, image_name, image_modified, image_size, recognized
            FROM thoughts
            """)
      }
    }
    var states: [ExactName: IndexState] = [:]
    for row in rows {
      var image: IndexedImage?
      if let name = row["image_name"] as String? {
        let modified = row["image_modified"] as Double?
        let size = row["image_size"] as Int?
        let version: FileVersion? =
          if let modified, let size {
            FileVersion(modified: Date(timeIntervalSinceReferenceDate: modified), size: size)
          } else {
            nil
          }
        image = IndexedImage(name: name, version: version)
      }
      states[ExactName(row["file"])] = IndexState(
        version: FileVersion(
          modified: Date(timeIntervalSinceReferenceDate: row["modified"]), size: row["size"]),
        image: image,
        recognized: row["recognized"]
      )
    }
    return states
  }

  func apply(_ rows: [IndexRow], removing names: [String]) throws -> IndexWrite {
    let folder = folder.withLock { $0 }
    return try Self.wrapped {
      try pool.writeWithoutTransaction { db in
        var write = IndexWrite()
        try db.inTransaction(.immediate) {
          let listing = try Listing(folder)
          for name in names where !(IndexSync.isMarkdownName(name) && listing.has(name)) {
            if try Self.delete(name, in: db) { write.removed.append(name) }
          }
          for row in rows {
            switch Self.disk(of: row.name, in: listing) {
            case .missing:
              if try Self.delete(row.name, in: db) { write.removed.append(row.name) }
              continue
            case .version(let version) where row.version.size >= 0 && version != row.version:
              continue
            default:
              break
            }
            let existed =
              try Bool.fetchOne(
                db, sql: "SELECT EXISTS (SELECT 1 FROM thoughts WHERE file = ?)",
                arguments: [row.name]) ?? false
            try Self.upsert(row, in: db)
            if existed {
              write.updated.append(row.name)
            } else {
              write.added.append(row.name)
            }
          }
          write.demoted = try Self.refreshDemotions(in: db)
          return .commit
        }
        return write
      }
    }
  }

  func applyRecognized(_ items: [RecognizedImage]) throws -> IndexWrite {
    let folder = folder.withLock { $0 }
    return try Self.wrapped {
      try pool.writeWithoutTransaction { db in
        var write = IndexWrite()
        try db.inTransaction(.immediate) {
          let listing = try Listing(folder)
          for item in items {
            switch Self.disk(of: item.name, in: listing) {
            case .missing:
              if try Self.delete(item.name, in: db) { write.removed.append(item.name) }
              continue
            case .unreadable:
              continue
            case .version:
              break
            }
            guard let version = item.image.version,
              case .version(let current) = Self.stat(item.image.name, in: folder),
              current == version
            else { continue }
            try db.execute(
              sql: """
                UPDATE thoughts SET recognized = ?
                WHERE file = ? AND image_name = ? AND image_modified IS ? AND image_size IS ?
                  AND recognized IS NULL
                """,
              arguments: [
                item.text, item.name, item.image.name,
                version.modified.timeIntervalSinceReferenceDate, version.size,
              ])
            if db.changesCount > 0 { write.updated.append(item.name) }
          }
          return .commit
        }
        return write
      }
    }
  }
}

struct IndexWrite {
  var added: [String] = []
  var updated: [String] = []
  var removed: [String] = []
  var demoted: [String] = []
}

struct RecognizedImage {
  var name: String
  var image: IndexedImage
  var text: String
}

extension SearchIndex {
  private enum Disk {
    case missing
    case version(FileVersion)
    case unreadable
  }

  private struct Listing {
    let folder: URL
    let names: Set<ExactName>

    init(_ folder: URL) throws {
      self.folder = folder
      guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else {
        throw ThoughtsError.storageUnavailable(folder.path)
      }
      self.names = Set(names.map(ExactName.init))
    }

    func has(_ name: String) -> Bool {
      guard names.contains(ExactName(name)) else { return false }
      return !ThoughtStore.isDirectory(folder.appendingPathComponent(name))
    }
  }

  private static func disk(of name: String, in listing: Listing) -> Disk {
    listing.has(name) ? stat(name, in: listing.folder) : .missing
  }

  private static func stat(_ name: String, in folder: URL) -> Disk {
    do {
      return .version(try AtomicFile.info(at: folder.appendingPathComponent(name)).version)
    } catch AtomicFileError.missing {
      return .missing
    } catch {
      return .unreadable
    }
  }

  private static func delete(_ name: String, in db: Database) throws -> Bool {
    try db.execute(sql: "DELETE FROM thoughts WHERE file = ?", arguments: [name])
    return db.changesCount > 0
  }

  private static func wrapped<T>(_ body: () throws -> T) throws -> T {
    do {
      return try body()
    } catch let error as ThoughtsError {
      throw error
    } catch let error as DatabaseError {
      throw ThoughtsError.io("The search index failed: \(error.description)")
    } catch {
      throw ThoughtsError.io("The search index failed: \(error.localizedDescription)")
    }
  }

  private static func path(of folder: URL) -> String {
    folder.standardizedFileURL.path
  }

  private static let busyTimeout: TimeInterval = 5

  private static func openPool(_ url: URL) throws -> DatabasePool {
    var configuration = Configuration()
    configuration.busyMode = .timeout(busyTimeout)
    do {
      let pool = try openRetryingWhileBusy(url, configuration)
      let version = try pool.read { try Int.fetchOne($0, sql: "PRAGMA user_version") ?? 0 }
      guard version == 0 || version == schemaVersion else {
        try pool.close()
        return try recreate(url, configuration)
      }
      return pool
    } catch let error as DatabaseError
      where error.resultCode.primaryResultCode == .SQLITE_NOTADB
      || error.resultCode.primaryResultCode == .SQLITE_CORRUPT
    {
      return try recreate(url, configuration)
    }
  }

  private static func recreate(_ url: URL, _ configuration: Configuration) throws -> DatabasePool {
    for suffix in ["", "-wal", "-shm"] {
      try? FileManager.default.removeItem(atPath: url.path + suffix)
    }
    return try openRetryingWhileBusy(url, configuration)
  }

  private static func openRetryingWhileBusy(
    _ url: URL, _ configuration: Configuration
  ) throws -> DatabasePool {
    let deadline = Date().addingTimeInterval(busyTimeout)
    while true {
      do {
        return try DatabasePool(path: url.path, configuration: configuration)
      } catch let error as DatabaseError
        where error.resultCode.primaryResultCode == .SQLITE_BUSY && Date() < deadline
      {
        Thread.sleep(forTimeInterval: .random(in: 0.005...0.05))
      }
    }
  }

  private static func prepare(_ pool: DatabasePool, folder: URL) throws {
    try pool.writeWithoutTransaction { db in
      try db.inTransaction(.immediate) {
        if try Int.fetchOne(db, sql: "PRAGMA user_version") == 0 {
          try createSchema(in: db)
        }
        let stored = try String.fetchOne(db, sql: "SELECT folder FROM meta")
        let current = path(of: folder)
        if stored == nil {
          try db.execute(sql: "INSERT INTO meta (id, folder) VALUES (1, ?)", arguments: [current])
        } else if stored != current {
          try db.execute(sql: "DELETE FROM thoughts")
          try db.execute(sql: "UPDATE meta SET folder = ?", arguments: [current])
        }
        return .commit
      }
    }
  }

  private static func createSchema(in db: Database) throws {
    try db.execute(
      sql: """
        CREATE TABLE meta (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          folder TEXT NOT NULL
        );
        CREATE TABLE thoughts (
          seq INTEGER PRIMARY KEY,
          file TEXT NOT NULL UNIQUE,
          modified REAL NOT NULL,
          size INTEGER NOT NULL,
          created REAL NOT NULL,
          birth REAL NOT NULL,
          id TEXT,
          entry TEXT NOT NULL,
          malformed INTEGER NOT NULL,
          demotion TEXT,
          text TEXT NOT NULL,
          note TEXT NOT NULL,
          source_text TEXT NOT NULL,
          recognized TEXT,
          image_name TEXT,
          image_modified REAL,
          image_size INTEGER
        );
        CREATE INDEX thoughts_created ON thoughts (created, file);
        """)
    try db.create(virtualTable: "thoughts_fts", using: FTS5()) { table in
      table.synchronize(withTable: "thoughts")
      table.tokenizer = .unicode61()
      table.column("text")
      table.column("note")
      table.column("recognized")
      table.column("source_text")
    }
    try db.execute(sql: "PRAGMA user_version = \(schemaVersion)")
  }

  private static func upsert(_ row: IndexRow, in db: Database) throws {
    let stored = StoredEntry(row.entry)
    let json = String(decoding: try JSONEncoder().encode(stored), as: UTF8.self)
    var id: String?
    var text = ""
    var note = ""
    var source = ""
    var malformed = true
    if case .thought(let thought) = row.entry {
      malformed = false
      id = thought.id.rawValue
      switch thought.content {
      case .text(let value): text = value
      case .image(_, let value): note = value
      }
      source = sourceText(thought.source)
    }
    try db.execute(
      sql: """
        INSERT INTO thoughts (
          file, modified, size, created, birth, id, entry, malformed, text, note, source_text,
          recognized, image_name, image_modified, image_size
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(file) DO UPDATE SET
          modified = excluded.modified, size = excluded.size, created = excluded.created, birth = excluded.birth,
          id = excluded.id, entry = excluded.entry, malformed = excluded.malformed,
          text = excluded.text, note = excluded.note, source_text = excluded.source_text,
          recognized = excluded.recognized, image_name = excluded.image_name,
          image_modified = excluded.image_modified, image_size = excluded.image_size
        """,
      arguments: [
        row.name,
        row.version.modified.timeIntervalSinceReferenceDate,
        row.version.size,
        row.created.timeIntervalSinceReferenceDate,
        row.birth.timeIntervalSinceReferenceDate,
        id,
        json,
        malformed ? 1 : 0,
        text,
        note,
        source,
        row.recognized,
        row.image?.name,
        row.image?.version?.modified.timeIntervalSinceReferenceDate,
        row.image?.version?.size,
      ])
  }

  private static func sourceText(_ source: Source?) -> String {
    guard let source else { return "" }
    return [
      source.app, source.bundleID, source.window, source.url?.absoluteString, source.title,
      source.file,
    ]
    .compactMap { $0 }
    .joined(separator: " ")
  }

  private static func refreshDemotions(in db: Database) throws -> [String] {
    let items = try Row.fetchAll(db, sql: "SELECT file, id FROM thoughts WHERE malformed = 0")
      .compactMap { row -> (id: ThoughtID, name: String)? in
        guard let id = ThoughtID(rawValue: row["id"]) else { return nil }
        return (id, row["file"])
      }
    let wanted = DuplicateIDs.demotions(items)
    var current: [String: String] = [:]
    for row in try Row.fetchAll(
      db, sql: "SELECT file, demotion FROM thoughts WHERE demotion IS NOT NULL")
    {
      current[row["file"]] = row["demotion"]
    }
    var changed: [String] = []
    for name in Set(wanted.keys).union(current.keys) where wanted[name] != current[name] {
      try db.execute(
        sql: "UPDATE thoughts SET demotion = ? WHERE file = ?", arguments: [wanted[name], name])
      changed.append(name)
    }
    return changed.sorted()
  }
}

private struct StoredEntry: Codable {
  var id: String?
  var created: Double?
  var done: Double?
  var cleared: Bool
  var image: String?
  var text: String
  var source: Source?
  var extraFrontMatter: String
  var extraSource: String
  var reason: String?

  init(_ entry: ThoughtEntry) {
    switch entry {
    case .thought(let thought):
      id = thought.id.rawValue
      created = thought.created.timeIntervalSinceReferenceDate
      done = thought.done?.timeIntervalSinceReferenceDate
      cleared = thought.cleared
      switch thought.content {
      case .text(let value):
        text = value
        image = nil
      case .image(let fileName, let note):
        text = note
        image = fileName
      }
      source = thought.source
      extraFrontMatter = thought.extraFrontMatter
      extraSource = thought.extraSource
      reason = nil
    case .malformed(_, let message):
      id = nil
      created = nil
      done = nil
      cleared = false
      image = nil
      text = ""
      source = nil
      extraFrontMatter = ""
      extraSource = ""
      reason = message
    }
  }

  static func decode(_ json: String, file: URL, version: FileVersion) -> ThoughtEntry {
    let unreadable = ThoughtEntry.malformed(
      file: file, reason: "The search index entry is unreadable")
    guard let stored = try? JSONDecoder().decode(StoredEntry.self, from: Data(json.utf8)) else {
      return unreadable
    }
    if let reason = stored.reason { return .malformed(file: file, reason: reason) }
    guard let rawID = stored.id, let id = ThoughtID(rawValue: rawID), let created = stored.created
    else { return unreadable }
    let content: ThoughtContent =
      stored.image.map { .image(fileName: $0, note: stored.text) } ?? .text(stored.text)
    return .thought(
      Thought(
        id: id,
        created: Date(timeIntervalSinceReferenceDate: created),
        done: stored.done.map { Date(timeIntervalSinceReferenceDate: $0) },
        cleared: stored.cleared,
        content: content,
        source: stored.source,
        extraFrontMatter: stored.extraFrontMatter,
        extraSource: stored.extraSource,
        file: file,
        version: version
      ))
  }
}

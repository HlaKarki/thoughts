import Foundation
import GRDB
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers

@testable import ThoughtsCore

private final class FakeRecognizer: TextRecognizing, Sendable {
  private let counter = Mutex(0)
  private let output: String

  init(_ output: String = "screenshot of an invoice") {
    self.output = output
  }

  var calls: Int { counter.withLock { $0 } }

  func text(in image: URL) throws -> String {
    counter.withLock { $0 += 1 }
    return output
  }
}

private final class Fixture {
  let scratch: URL
  let folder: URL
  let indexURL: URL
  let recognizer = FakeRecognizer()
  let store: ThoughtStore
  var index: SearchIndex

  init() {
    scratch = FileManager.default.temporaryDirectory
      .appendingPathComponent("index-tests-\(UUID().uuidString)")
    folder = scratch.appendingPathComponent("Thoughts")
    indexURL = scratch.appendingPathComponent("Support/index.sqlite")
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    store = ThoughtStore(folder: folder, trash: { try FileManager.default.removeItem(at: $0) })
    index = try! SearchIndex(url: indexURL, folder: folder)
  }

  deinit {
    try? FileManager.default.removeItem(at: scratch)
  }

  var sync: IndexSync { IndexSync(store: store, index: index, recognizer: recognizer) }

  func addText(_ text: String, source: Source? = nil) -> Thought {
    try! store.add(NewThought(content: .text(text), source: source, created: Date()))
  }

  func addImage(note: String = "") -> Thought {
    try! store.add(NewThought(content: .image(.data(tinyPNG(), .png), note: note)))
  }

  func writeFile(_ name: String, id: String, body: String = "body") {
    let text = "---\nid: \(id)\ncreated: 2026-11-22T10:10:10.000+00:00\n---\n\(body)\n"
    try! text.write(
      to: folder.appendingPathComponent(name), atomically: false, encoding: .utf8)
  }

  func entries() -> [ThoughtEntry] {
    try! index.entries(includeCleared: true)
  }
}

private func tinyPNG() -> Data {
  let context = CGContext(
    data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
  context.setFillColor(gray: 0.5, alpha: 1)
  context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
  let data = NSMutableData()
  let destination = CGImageDestinationCreateWithData(
    data, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, context.makeImage()!, nil)
  precondition(CGImageDestinationFinalize(destination))
  return data as Data
}

@Test func reconcileIndexesNewFiles() throws {
  let fx = Fixture()
  let first = fx.addText("buy milk")
  let second = fx.addText("call mom")
  let image = fx.addImage(note: "receipt")
  let changes = try fx.sync.reconcile(nil)
  let names = [first, second, image].map(\.file.lastPathComponent).sorted()
  #expect(changes.added == names)
  #expect(changes.updated.isEmpty)
  #expect(changes.removed.isEmpty)
  #expect(fx.entries() == (try fx.store.entries()))
  #expect(try fx.sync.reconcile(nil).isEmpty)
}

@Test func reconcileSeesEditsAndDeletes() throws {
  let fx = Fixture()
  let keep = fx.addText("buy milk")
  let edit = fx.addText("call mom")
  let drop = fx.addText("water plants")
  _ = try fx.sync.reconcile(nil)

  _ = try fx.store.setText("call mom tonight", of: edit.id, expected: edit.version)
  try FileManager.default.removeItem(at: drop.file)
  let changes = try fx.sync.reconcile(nil)
  #expect(changes.added.isEmpty)
  #expect(changes.updated == [edit.file.lastPathComponent])
  #expect(changes.removed == [drop.file.lastPathComponent])
  #expect(fx.entries() == (try fx.store.entries()))
  #expect(try fx.index.search("tonight") == [edit.id])
  #expect(try fx.index.search("water").isEmpty)
  #expect(fx.entries().count == 2)

  let partial = try fx.sync.reconcile([keep.file])
  #expect(partial.isEmpty)
  try FileManager.default.removeItem(at: keep.file)
  #expect(try fx.sync.reconcile([keep.file]).removed == [keep.file.lastPathComponent])
}

@Test func rebuildFromFilesMatchesReconcile() throws {
  let fx = Fixture()
  _ = fx.addText("buy milk")
  _ = fx.addImage(note: "receipt")
  fx.writeFile("broken.md", id: "bad/id")
  _ = try fx.sync.reconcile(nil)
  let before = fx.entries()
  #expect(fx.recognizer.calls == 1)

  let rebuilt = try fx.sync.rebuild()
  #expect(rebuilt.updated.count == 3)
  #expect(fx.entries() == before)
  #expect(fx.recognizer.calls == 1)

  let source = fx.indexURL.path
  for suffix in ["", "-wal", "-shm"] {
    try? FileManager.default.removeItem(atPath: source + suffix)
  }
  fx.index = try SearchIndex(url: fx.indexURL, folder: fx.folder)
  let fresh = try fx.sync.rebuild()
  #expect(fresh.added.count == 3)
  #expect(fx.entries() == before)
  #expect(fx.entries() == (try fx.store.entries()))
}

@Test func searchMatchesTextNoteOCRAndSource() throws {
  let fx = Fixture()
  let text = fx.addText("buy milk", source: Source(app: "Safari", title: "Quarterly Report"))
  let image = fx.addImage(note: "diagram note")
  _ = try fx.sync.reconcile(nil)
  #expect(try fx.index.search("scre") == [image.id])
  #expect(try fx.index.search("mil") == [text.id])
  #expect(try fx.index.search("diagr") == [image.id])
  #expect(try fx.index.search("quart saf") == [text.id])
  #expect(try fx.index.search("buy invoice").isEmpty)
  #expect(try fx.index.search("zzz").isEmpty)
  #expect(try fx.index.search("   ").isEmpty)
  #expect(try fx.index.search("").isEmpty)
}

@Test func searchOrdersByCreated() throws {
  let fx = Fixture()
  let late = try fx.store.add(
    NewThought(content: .text("shared word later"), created: Date(timeIntervalSince1970: 2_000)))
  let early = try fx.store.add(
    NewThought(content: .text("shared word earlier"), created: Date(timeIntervalSince1970: 1_000)))
  _ = try fx.sync.reconcile(nil)
  #expect(try fx.index.search("shared") == [early.id, late.id])
}

@Test func searchIncludesClearedButEntriesCanHideThem() throws {
  let fx = Fixture()
  let done = fx.addText("ship it")
  let open = fx.addText("ship later")
  _ = try fx.store.setDone(true, for: done.id, at: Date())
  _ = try fx.store.clearDone()
  _ = try fx.sync.reconcile(nil)
  #expect(try fx.index.entries(includeCleared: true).count == 2)
  let visible = try fx.index.entries(includeCleared: false)
  #expect(visible.count == 1)
  guard case .thought(let thought) = visible[0] else {
    Issue.record("not a thought")
    return
  }
  #expect(thought.id == open.id)
  #expect(Set(try fx.index.search("ship")) == [done.id, open.id])
}

@Test func recognizesUnchangedImageOnlyOnce() throws {
  let fx = Fixture()
  let image = fx.addImage(note: "first")
  _ = try fx.sync.reconcile(nil)
  _ = try fx.sync.reconcile(nil)
  #expect(fx.recognizer.calls == 1)
  _ = try fx.store.setText("second", of: image.id, expected: image.version)
  let changes = try fx.sync.reconcile(nil)
  #expect(changes.updated == [image.file.lastPathComponent])
  #expect(fx.recognizer.calls == 1)
  #expect(try fx.index.search("invoice") == [image.id])
}

@Test func recognizesImageAgainWhenItChanges() throws {
  let fx = Fixture()
  let image = fx.addImage()
  _ = try fx.sync.reconcile(nil)
  let url = try #require(fx.store.imageURL(of: image))
  var bigger = tinyPNG()
  bigger.append(Data(repeating: 0, count: 16))
  try bigger.write(to: url)
  _ = try fx.sync.reconcile(nil)
  #expect(fx.recognizer.calls == 2)
}

@Test func recognizesLaterWhenNoRecognizerWasGiven() throws {
  let fx = Fixture()
  let image = fx.addImage()
  _ = try IndexSync(store: fx.store, index: fx.index, recognizer: nil).reconcile(nil)
  #expect(try fx.index.search("invoice").isEmpty)
  let changes = try fx.sync.reconcile(nil)
  #expect(changes.updated == [image.file.lastPathComponent])
  #expect(try fx.index.search("invoice") == [image.id])
}

@Test func bulkAddReconcilesInOnePass() throws {
  let fx = Fixture()
  for number in 0..<1_000 {
    fx.writeFile(
      String(format: "20261122-101010-bulk%04d.md", number), id: String(format: "bulk%04d", number),
      body: "bulk thought \(number)")
  }
  let changes = try fx.sync.reconcile(nil)
  #expect(changes.added.count == 1_000)
  #expect(fx.entries().count == 1_000)
  #expect(try fx.index.search("bulk").count == 1_000)
  #expect(try fx.sync.reconcile(nil).isEmpty)
}

@Test func openingForAnotherFolderClearsRows() throws {
  let fx = Fixture()
  _ = fx.addText("buy milk")
  _ = try fx.sync.reconcile(nil)
  #expect(fx.entries().count == 1)

  let other = fx.scratch.appendingPathComponent("Other")
  try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
  let moved = try SearchIndex(url: fx.indexURL, folder: other)
  #expect(try moved.entries(includeCleared: true).isEmpty)
  #expect(try moved.search("milk").isEmpty)

  let same = try SearchIndex(url: fx.indexURL, folder: other)
  _ = try IndexSync(store: ThoughtStore(folder: other), index: same, recognizer: nil)
    .reconcile(nil)
  #expect(try same.entries(includeCleared: true).isEmpty)
}

@Test func relocateKeepsRecognizedText() throws {
  let fx = Fixture()
  let image = fx.addImage(note: "receipt")
  _ = try fx.sync.reconcile(nil)
  #expect(fx.recognizer.calls == 1)

  let destination = fx.scratch.appendingPathComponent("Moved")
  try FileManager.default.moveItem(at: fx.folder, to: destination)
  try fx.index.relocate(to: destination)

  let reopened = try SearchIndex(url: fx.indexURL, folder: destination)
  let moved = IndexSync(
    store: ThoughtStore(folder: destination), index: reopened, recognizer: fx.recognizer)
  let changes = try moved.reconcile(nil)
  #expect(changes.isEmpty)
  #expect(fx.recognizer.calls == 1)
  #expect(try reopened.search("invoice") == [image.id])
  #expect(
    try reopened.entries(includeCleared: true) == (try ThoughtStore(folder: destination).entries()))
}

@Test func duplicateIDCopyIsMalformedInIndex() throws {
  let fx = Fixture()
  fx.writeFile("20261122-101010-dupe0001.md", id: "dupe0001", body: "original")
  fx.writeFile("20261122-101010-dupe0001 copy.md", id: "dupe0001", body: "copy")
  _ = try fx.sync.reconcile(nil)
  let entries = fx.entries()
  #expect(entries == (try fx.store.entries()))
  let malformed = entries.filter {
    if case .malformed = $0 { return true }
    return false
  }
  #expect(malformed.count == 1)
  guard case .malformed(let file, let reason) = malformed[0] else { return }
  #expect(file.lastPathComponent == "20261122-101010-dupe0001 copy.md")
  #expect(reason.contains("20261122-101010-dupe0001.md"))
  #expect(try fx.index.search("copy").isEmpty)
  #expect(try fx.index.search("original").map(\.rawValue) == ["dupe0001"])

  try FileManager.default.removeItem(
    at: fx.folder.appendingPathComponent("20261122-101010-dupe0001.md"))
  let changes = try fx.sync.reconcile(nil)
  #expect(changes.updated == ["20261122-101010-dupe0001 copy.md"])
  #expect(fx.entries() == (try fx.store.entries()))
  #expect(try fx.index.search("copy").map(\.rawValue) == ["dupe0001"])
}

@Test func searchTreatsOperatorsAsText() throws {
  let fx = Fixture()
  let hit = fx.addText("fix: \"crash\" OR -x (NEAR")
  _ = fx.addText("something else")
  _ = try fx.sync.reconcile(nil)
  #expect(try fx.index.search("fix: \"crash\" OR -x (NEAR") == [hit.id])
  for query in ["\"", "(", "*", "a AND", "NOT", "col:val", "\"\"", "-", "NEAR(", "'"] {
    _ = try fx.index.search(query)
  }
  #expect(try fx.index.search("crash") == [hit.id])
}

@Test func schemaMismatchRecreatesIndex() throws {
  let fx = Fixture()
  let thought = fx.addText("buy milk")
  _ = try fx.sync.reconcile(nil)
  let raw = try DatabasePool(path: fx.indexURL.path)
  try raw.write { try $0.execute(sql: "PRAGMA user_version = 999") }
  try raw.close()

  fx.index = try SearchIndex(url: fx.indexURL, folder: fx.folder)
  #expect(fx.entries().isEmpty)
  let changes = try fx.sync.reconcile(nil)
  #expect(changes.added == [thought.file.lastPathComponent])
  #expect(try fx.index.search("milk") == [thought.id])
}

@Test func secondPoolWaitsForWriter() throws {
  let fx = Fixture()
  _ = fx.addText("buy milk")
  _ = try fx.sync.reconcile(nil)
  _ = fx.addText("call mom")

  let holder = try DatabasePool(path: fx.indexURL.path)
  let locked = DispatchSemaphore(value: 0)
  let released = DispatchSemaphore(value: 0)
  let failure = Mutex<(any Error)?>(nil)
  DispatchQueue.global().async {
    do {
      try holder.writeWithoutTransaction { db in
        try db.inTransaction(.immediate) {
          try db.execute(sql: "UPDATE meta SET folder = folder")
          locked.signal()
          Thread.sleep(forTimeInterval: 1)
          return .commit
        }
      }
    } catch {
      failure.withLock { $0 = error }
      locked.signal()
    }
    released.signal()
  }
  locked.wait()
  let started = Date()
  let other = try SearchIndex(url: fx.indexURL, folder: fx.folder)
  let changes = try IndexSync(store: fx.store, index: other, recognizer: fx.recognizer)
    .reconcile(nil)
  #expect(Date().timeIntervalSince(started) > 0.3)
  #expect(changes.added.count == 1)
  released.wait()
  #expect(failure.withLock { $0 } == nil)
}

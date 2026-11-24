import Darwin
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
  private let failing = Mutex(Set<String>())
  private let onCall: (@Sendable (URL) -> Void)?

  init(_ output: String = "screenshot of an invoice", onCall: (@Sendable (URL) -> Void)? = nil) {
    self.output = output
    self.onCall = onCall
  }

  var calls: Int { counter.withLock { $0 } }

  func fail(on name: String) {
    failing.withLock { _ = $0.insert(name) }
  }

  func text(in image: URL) throws -> String {
    counter.withLock { $0 += 1 }
    onCall?(image)
    if failing.withLock({ $0.contains(image.lastPathComponent) }) {
      throw ThoughtsError.io("unreadable image")
    }
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
    store = ThoughtStore(
      folder: folder,
      trash: { url in
        try FileManager.default.removeItem(at: url)
        return url
      })
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

@Test func imageTextExcerptsQuoteRecognizedTextOnly() throws {
  let fx = Fixture()
  let text = fx.addText("invoice reminder")
  let image = fx.addImage(note: "diagram note")
  _ = try fx.sync.reconcile(nil)
  let excerpts = try fx.index.imageTextExcerpts(for: [text.id, image.id], query: "invo")
  #expect(excerpts[text.id] == nil)
  #expect(excerpts[image.id]?.contains("invoice") == true)
  #expect(try fx.index.imageTextExcerpts(for: [image.id], query: "diagr").isEmpty)
  #expect(try fx.index.imageTextExcerpts(for: [], query: "invo").isEmpty)
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

@Test func failedRecognitionIsNotRetriedUntilImageChanges() throws {
  let fx = Fixture()
  let image = fx.addImage()
  let url = try #require(fx.store.imageURL(of: image))
  fx.recognizer.fail(on: url.lastPathComponent)
  let first = try fx.sync.reconcile(nil)
  #expect(first.added == [image.file.lastPathComponent])
  #expect(fx.recognizer.calls == 1)

  let second = try fx.sync.reconcile(nil)
  #expect(second.isEmpty)
  #expect(fx.recognizer.calls == 1)

  var bigger = tinyPNG()
  bigger.append(Data(repeating: 0, count: 16))
  try bigger.write(to: url)
  let changed = try fx.sync.reconcile(nil)
  #expect(changed.updated == [image.file.lastPathComponent])
  #expect(fx.recognizer.calls == 2)
  #expect(try fx.sync.reconcile(nil).isEmpty)
  #expect(fx.recognizer.calls == 2)

  _ = try fx.sync.rebuild()
  #expect(fx.recognizer.calls == 3)
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
  let milk = fx.addText("buy milk")
  let rust = fx.addText("notes about rust and swift")
  _ = try fx.sync.reconcile(nil)
  #expect(try fx.index.search("fix: \"crash\" OR -x (NEAR") == [hit.id])
  #expect(try fx.index.search("buy - milk") == [milk.id])
  #expect(try fx.index.search("buy & milk") == [milk.id])
  #expect(try fx.index.search("milk :") == [milk.id])
  #expect(try fx.index.search("rust / swift") == [rust.id])
  #expect(try fx.index.search("rust + swift") == [rust.id])
  #expect(try fx.index.search("- & /").isEmpty)
  for query in ["\"", "(", "*", "a AND", "NOT", "col:val", "\"\"", "-", "NEAR(", "'"] {
    _ = try fx.index.search(query)
  }
  #expect(try fx.index.search("crash") == [hit.id])
}

@Test func staleReconcileKeepsIndexMatchingFiles() throws {
  for edit in [false, true] {
    let fx = Fixture()
    let image = fx.addImage(note: "first")
    let other = try SearchIndex(url: fx.indexURL, folder: fx.folder)
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let blocking = FakeRecognizer(onCall: { _ in
      entered.signal()
      release.wait()
    })
    let finished = DispatchSemaphore(value: 0)
    let failure = Mutex<(any Error)?>(nil)
    let slow = IndexSync(store: fx.store, index: fx.index, recognizer: blocking)
    DispatchQueue.global().async {
      do { _ = try slow.reconcile(nil) } catch { failure.withLock { $0 = error } }
      finished.signal()
    }
    entered.wait()

    let quick = IndexSync(store: fx.store, index: other, recognizer: nil)
    if edit {
      _ = try fx.store.setText("second", of: image.id, expected: image.version)
    } else {
      try FileManager.default.removeItem(at: image.file)
    }
    _ = try quick.reconcile([image.file])
    release.signal()
    finished.wait()

    #expect(failure.withLock { $0 } == nil)
    #expect(try fx.index.entries(includeCleared: true) == (try fx.store.entries()))
    #expect(try other.entries(includeCleared: true) == (try fx.store.entries()))
    if edit { #expect(try fx.index.search("second") == [image.id]) }
  }
}

@Test func staleRowIsNotWrittenOverNewerFile() throws {
  let fx = Fixture()
  let old = fx.addText("first")
  _ = try fx.sync.reconcile(nil)
  let staleRow = IndexRow(
    name: old.file.lastPathComponent, entry: .thought(old), version: old.version,
    created: old.created, birth: old.created, image: nil, recognized: nil)
  _ = try fx.store.setText("second", of: old.id, expected: old.version)
  _ = try fx.index.apply([staleRow], removing: [])
  _ = try fx.sync.reconcile(nil)
  #expect(fx.entries() == (try fx.store.entries()))
  _ = try fx.index.apply([staleRow], removing: [])
  #expect(try fx.index.search("second") == [old.id])
  try FileManager.default.removeItem(at: old.file)
  _ = try fx.index.apply([staleRow], removing: [])
  #expect(fx.entries().isEmpty)
}

private func rename(in folder: URL, _ from: String, to: String) -> Bool {
  Darwin.rename(folder.path + "/" + from, folder.path + "/" + to) == 0
}

@Test func caseOnlyRenameLeavesOneEntry() throws {
  let fx = Fixture()
  fx.writeFile("20261122-101010-caseid01.md", id: "caseid01", body: "renamed")
  _ = try fx.sync.reconcile(nil)
  try #require(
    rename(in: fx.folder, "20261122-101010-caseid01.md", to: "20261122-101010-CASEID01.md"))
  _ = try fx.sync.reconcile(nil)
  let entries = fx.entries()
  #expect(entries == (try fx.store.entries()))
  #expect(entries.count == 1)
  guard case .thought = entries[0] else {
    Issue.record("not a thought")
    return
  }
  _ = try fx.sync.rebuild()
  #expect(fx.entries() == (try fx.store.entries()))
}

@Test func normalizationOnlyRenameLeavesOneEntry() throws {
  let fx = Fixture()
  let spellings = ["caf\u{E9}.md", "cafe\u{301}.md"]
  try "hello".write(
    to: fx.folder.appendingPathComponent(spellings[0]), atomically: false, encoding: .utf8)
  _ = try fx.sync.reconcile(nil)
  let before = try FileManager.default.contentsOfDirectory(atPath: fx.folder.path)
  let target = spellings.first { !$0.utf8.elementsEqual(before[0].utf8) }!
  try #require(rename(in: fx.folder, before[0], to: target))
  let after = try FileManager.default.contentsOfDirectory(atPath: fx.folder.path)
  try #require(after.count == 1)
  try #require(!after[0].utf8.elementsEqual(before[0].utf8))
  let changes = try fx.sync.reconcile(nil)
  #expect(changes.added.count == 1)
  #expect(changes.removed.count == 1)
  let entries = fx.entries()
  #expect(entries == (try fx.store.entries()))
  #expect(entries.count == 1)
}

private func makeNFCFile(_ fx: Fixture) throws -> String {
  let composed = "caf\u{E9}-nfc00001.md"
  let decomposed = "cafe\u{301}-nfc00001.md"
  try "hello".write(
    to: fx.folder.appendingPathComponent(decomposed), atomically: false, encoding: .utf8)
  try #require(rename(in: fx.folder, decomposed, to: composed))
  let listed = try FileManager.default.contentsOfDirectory(atPath: fx.folder.path)
  try #require(listed.count == 1)
  try #require(listed[0].utf8.elementsEqual(composed.utf8))
  return listed[0]
}

@Test func reconcileFilesAfterCaseRenameLeavesOneEntry() throws {
  let fx = Fixture()
  fx.writeFile("20261122-101010-caseid01.md", id: "caseid01", body: "renamed")
  _ = try fx.sync.reconcile(nil)
  try #require(
    rename(in: fx.folder, "20261122-101010-caseid01.md", to: "20261122-101010-CASEID01.md"))
  let old = fx.folder.appendingPathComponent("20261122-101010-caseid01.md")
  let new = fx.folder.appendingPathComponent("20261122-101010-CASEID01.md")
  let changes = try fx.sync.reconcile([old, new])
  #expect(changes.removed == ["20261122-101010-caseid01.md"])
  #expect(changes.added == ["20261122-101010-CASEID01.md"])
  let entries = fx.entries()
  #expect(entries == (try fx.store.entries()))
  #expect(entries.count == 1)
  if case .malformed = entries.first { Issue.record("malformed entry") }
}

@Test func reconcileFilesWithEitherNameAfterCaseRenameLeavesOneEntry() throws {
  let old = "20261122-101010-caseid01.md"
  let new = "20261122-101010-CASEID01.md"
  for caller in [old, new] {
    let fx = Fixture()
    fx.writeFile(old, id: "caseid01", body: "renamed")
    _ = try fx.sync.reconcile(nil)
    try #require(rename(in: fx.folder, old, to: new))
    let changes = try fx.sync.reconcile([fx.folder.appendingPathComponent(caller)])
    #expect(changes.removed == [old])
    #expect(changes.added == [new])
    #expect(fx.entries() == (try fx.store.entries()))
  }
}

private func onlyName(in fx: Fixture) throws -> String? {
  let listed = try FileManager.default.contentsOfDirectory(atPath: fx.folder.path)
  return listed.count == 1 ? listed[0] : nil
}

@Test func reconcileFilesAfterNormalizationRenameLeavesOneEntry() throws {
  let composed = "caf\u{E9}-norm0001.md"
  let decomposed = "cafe\u{301}-norm0001.md"
  for (old, new) in [(decomposed, composed), (composed, decomposed)] {
    let fx = Fixture()
    fx.writeFile(decomposed, id: "norm0001")
    if !old.utf8.elementsEqual(decomposed.utf8) {
      try #require(rename(in: fx.folder, decomposed, to: old))
    }
    try #require(try onlyName(in: fx)?.utf8.elementsEqual(old.utf8) == true)
    _ = try fx.sync.reconcile(nil)
    try #require(rename(in: fx.folder, old, to: new))
    try #require(try onlyName(in: fx)?.utf8.elementsEqual(new.utf8) == true)
    let changes = try fx.sync.reconcile([old, new].map { fx.folder.appendingPathComponent($0) })
    #expect(changes.removed.count == 1)
    #expect(changes.removed.first?.utf8.elementsEqual(old.utf8) == true)
    #expect(changes.added.count == 1)
    #expect(changes.added.first?.utf8.elementsEqual(new.utf8) == true)
    let entries = fx.entries()
    #expect(entries == (try fx.store.entries()))
    #expect(entries.count == 1)
    #expect(!entries.contains { if case .malformed = $0 { true } else { false } })
  }
}

@Test func reconcileFilesUpdatesNFCNamedFile() throws {
  let fx = Fixture()
  let name = try makeNFCFile(fx)
  _ = try fx.sync.reconcile(nil)
  let url = fx.folder.appendingPathComponent(name)
  try "hello zebra".write(to: url, atomically: false, encoding: .utf8)
  let changes = try fx.sync.reconcile([url])
  #expect(changes.updated.count == 1)
  #expect(changes.updated.first?.utf8.elementsEqual(name.utf8) == true)
  #expect(try fx.index.search("zebra").count == 1)
  #expect(fx.entries() == (try fx.store.entries()))
}

@Test func reconcileFilesRemovesDeletedNFCNamedFile() throws {
  let fx = Fixture()
  let name = try makeNFCFile(fx)
  _ = try fx.sync.reconcile(nil)
  let url = fx.folder.appendingPathComponent(name)
  try FileManager.default.removeItem(at: url)
  let changes = try fx.sync.reconcile([url])
  #expect(changes.removed.count == 1)
  #expect(fx.entries().isEmpty)
}

@Test func symlinkedDirectoryNameMatchesStore() throws {
  let fx = Fixture()
  let target = fx.scratch.appendingPathComponent("elsewhere")
  try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
  try FileManager.default.createSymbolicLink(
    at: fx.folder.appendingPathComponent("linkdir.md"), withDestinationURL: target)
  _ = try fx.sync.reconcile(nil)
  #expect(fx.entries() == (try fx.store.entries()))
  #expect(fx.entries().count == 1)
  #expect(try fx.sync.reconcile(nil).isEmpty)
  #expect(fx.entries() == (try fx.store.entries()))
}

@Test func restoredFileKeepsItsRow() throws {
  let fx = Fixture()
  let thought = fx.addText("buy milk")
  _ = try fx.sync.reconcile(nil)
  let name = thought.file.lastPathComponent
  let write = try fx.index.apply([], removing: [name])
  #expect(write.removed.isEmpty)
  #expect(fx.entries() == (try fx.store.entries()))
  #expect(try fx.index.search("milk") == [thought.id])
}

@Test func directoryWithAThoughtNameIsNotRestored() throws {
  let fx = Fixture()
  let thought = fx.addText("buy milk")
  _ = try fx.sync.reconcile(nil)
  try FileManager.default.removeItem(at: thought.file)
  try FileManager.default.createDirectory(at: thought.file, withIntermediateDirectories: false)
  let changes = try fx.sync.reconcile(nil)
  #expect(changes.removed == [thought.file.lastPathComponent])
  #expect(fx.entries().isEmpty)
}

@Test func rowsAreVisibleBeforeRecognitionFinishes() throws {
  let fx = Fixture()
  _ = fx.addText("buy milk")
  _ = fx.addImage(note: "one")
  _ = fx.addImage(note: "two")
  let seen = Mutex<[Int]>([])
  let url = fx.indexURL
  let folder = fx.folder
  let recognizer = FakeRecognizer(onCall: { _ in
    let other = try? SearchIndex(url: url, folder: folder)
    let count = (try? other?.entries(includeCleared: true).count) ?? -1
    seen.withLock { $0.append(count) }
  })
  _ = try IndexSync(store: fx.store, index: fx.index, recognizer: recognizer).reconcile(nil)
  #expect(seen.withLock { $0 }.first == 3)
  #expect(recognizer.calls == 2)
}

@Test func recognizingPassAfterPlainPassReportsUpdated() throws {
  let fx = Fixture()
  _ = fx.addText("buy milk")
  let first = fx.addImage(note: "one")
  let second = fx.addImage(note: "two")
  let plain = try IndexSync(store: fx.store, index: fx.index, recognizer: nil).reconcile(nil)
  #expect(plain.added.count == 3)
  #expect(fx.recognizer.calls == 0)
  let changes = try fx.sync.reconcile(nil)
  #expect(changes.added.isEmpty)
  #expect(changes.updated == [first, second].map(\.file.lastPathComponent).sorted())
  #expect(fx.recognizer.calls == 2)
  #expect(try fx.index.search("invoice").count == 2)
  #expect(try fx.sync.reconcile(nil).isEmpty)
  #expect(fx.recognizer.calls == 2)
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

@Test func aLateFailedRecognitionNeverReplacesRecognizedText() throws {
  let fx = Fixture()
  let image = fx.addImage()
  _ = try fx.sync.reconcile(nil)
  let name = image.file.lastPathComponent
  let state = try #require(try fx.index.states()[ExactName(name)])
  #expect(state.recognized == "screenshot of an invoice")
  let indexed = try #require(state.image)

  let write = try fx.index.applyRecognized([RecognizedImage(name: name, image: indexed, text: "")])
  #expect(write.updated.isEmpty)
  #expect(try fx.index.states()[ExactName(name)]?.recognized == "screenshot of an invoice")
  #expect(try fx.index.search("invoice") == [image.id])
}

@Test func reconcileScopeMatchesNamesTheDiskTreatsAsOne() {
  let pairs = [("STRASSE.md", "Straße.md"), ("FILE.md", "ﬁle.md"), ("ΟΔΟΣ.md", "οδος.md")]
  for (listed, stored) in pairs {
    let plan = IndexSync.ReconcilePlan(listed: [listed], stored: [stored], scope: [listed])
    #expect(plan.load == [listed])
    #expect(plan.remove == [stored])
  }
}

@Test func concurrentOpensOfAFreshIndexAllSucceed() throws {
  let scratch = FileManager.default.temporaryDirectory
    .appendingPathComponent("index-open-\(UUID().uuidString)")
  let folder = scratch.appendingPathComponent("Thoughts")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: scratch) }
  let openers = 4
  let failures = Mutex<[String]>([])
  for round in 0..<20 {
    let url = scratch.appendingPathComponent("Support-\(round)/index.sqlite")
    let opened = Mutex<[SearchIndex]>([])
    let gate = DispatchSemaphore(value: 0)
    let finished = DispatchGroup()
    for _ in 0..<openers {
      finished.enter()
      Thread.detachNewThread {
        gate.wait()
        do {
          let index = try SearchIndex(url: url, folder: folder)
          opened.withLock { $0.append(index) }
        } catch {
          failures.withLock { $0.append(String(describing: error)) }
        }
        finished.leave()
      }
    }
    for _ in 0..<openers { gate.signal() }
    finished.wait()
    for index in opened.withLock({ $0 }) { try index.close() }
  }
  #expect(failures.withLock { $0 } == [])
}

import Darwin
import Foundation
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers

@testable import ThoughtsCore

private final class Scratch {
  let root: URL
  let folder: URL
  let support: URL

  init() {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("watch-tests-\(UUID().uuidString)")
    folder = root.appendingPathComponent("Thoughts")
    support = root.appendingPathComponent("Support")
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  deinit {
    try? FileManager.default.removeItem(at: root)
  }

  var location: StorageLocation {
    StorageLocation(environment: ["THOUGHTS_DIR": folder.path], home: root)
  }

  var store: ThoughtStore {
    ThoughtStore(folder: folder, trash: { try FileManager.default.removeItem(at: $0) })
  }

  func makeIndex() throws -> SearchIndex {
    try SearchIndex(url: support.appendingPathComponent("index.sqlite"), folder: folder)
  }
}

private final class Batches: Sendable {
  private let state = Mutex<[[String]]>([])

  var count: Int { state.withLock { $0.count } }
  var names: Set<String> { state.withLock { Set($0.flatMap { $0 }) } }

  func record(_ urls: [URL]) {
    state.withLock { $0.append(urls.map(\.lastPathComponent)) }
  }
}

private final class Deliveries: Sendable {
  private let state = Mutex<[Result<IndexChanges, ThoughtsError>]>([])

  var count: Int { state.withLock { $0.count } }

  var changes: [IndexChanges] {
    state.withLock { $0.compactMap { try? $0.get() } }
  }

  var failures: [ThoughtsError] {
    state.withLock {
      $0.compactMap { result in
        if case .failure(let error) = result { error } else { nil }
      }
    }
  }

  func record(_ result: Result<IndexChanges, ThoughtsError>) {
    state.withLock { $0.append(result) }
  }

  func sawUpdate(of name: String) -> Bool {
    changes.contains { $0.updated.contains { $0.utf8.elementsEqual(name.utf8) } }
  }
}

private final class FakeRecognizer: TextRecognizing, Sendable {
  private let counter = Mutex(0)

  var calls: Int { counter.withLock { $0 } }

  func text(in image: URL) throws -> String {
    counter.withLock { $0 += 1 }
    return "invoice"
  }
}

private func eventually(
  seconds: Double = 5, _ condition: @Sendable () -> Bool
) async -> Bool {
  let deadline = Date().addingTimeInterval(seconds)
  while Date() < deadline {
    if condition() { return true }
    try? await Task.sleep(for: .milliseconds(20))
  }
  return condition()
}

private func png(side: Int) -> Data {
  let context = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
  context.setFillColor(gray: 0.5, alpha: 1)
  context.fill(CGRect(x: 0, y: 0, width: side, height: side))
  let data = NSMutableData()
  let destination = CGImageDestinationCreateWithData(
    data, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, context.makeImage()!, nil)
  precondition(CGImageDestinationFinalize(destination))
  return data as Data
}

private func makeWatcher(
  _ scratch: Scratch, _ batches: Batches, queue: DispatchQueue = DispatchQueue(label: "test.watch")
) -> FolderWatcher {
  FolderWatcher(folder: scratch.folder, latency: 0.1, queue: queue) { batches.record($0) }
}

@Test func reportsAddedFile() async throws {
  let scratch = Scratch()
  let batches = Batches()
  let watcher = makeWatcher(scratch, batches)
  try watcher.start()
  defer { watcher.stop() }
  try "hello".write(
    to: scratch.folder.appendingPathComponent("added.md"), atomically: true, encoding: .utf8)
  #expect(await eventually { batches.names.contains("added.md") })
}

@Test func ignoresTemporaryDotFiles() async throws {
  let scratch = Scratch()
  let batches = Batches()
  let watcher = makeWatcher(scratch, batches)
  try watcher.start()
  defer { watcher.stop() }
  let temporary = ".note.md.tmp-\(UUID().uuidString)"
  try "x".write(
    to: scratch.folder.appendingPathComponent(temporary), atomically: false, encoding: .utf8)
  try "y".write(
    to: scratch.folder.appendingPathComponent("real.md"), atomically: false, encoding: .utf8)
  #expect(await eventually { batches.names.contains("real.md") })
  #expect(!batches.names.contains { $0.hasPrefix(".") })
}

@Test func burstArrivesInFewBatches() async throws {
  let scratch = Scratch()
  let batches = Batches()
  let watcher = makeWatcher(scratch, batches)
  try watcher.start()
  defer { watcher.stop() }
  let expected = Set((0..<200).map { "burst-\($0).md" })
  for name in expected {
    try "x".write(
      to: scratch.folder.appendingPathComponent(name), atomically: false, encoding: .utf8)
  }
  #expect(await eventually { expected.isSubset(of: batches.names) })
  #expect(batches.count < 20)
}

@Test func stopEndsCallbacks() async throws {
  let scratch = Scratch()
  let batches = Batches()
  let deliveries = Deliveries()
  let index = try scratch.makeIndex()
  let live = LiveIndex(location: scratch.location, index: index, recognizer: nil)
  let watcher = makeWatcher(scratch, batches)
  try watcher.start()
  try live.start { deliveries.record($0) }
  try "one".write(
    to: scratch.folder.appendingPathComponent("one.md"), atomically: true, encoding: .utf8)
  #expect(await eventually { batches.names.contains("one.md") && deliveries.count > 0 })

  watcher.stop()
  live.stop()
  let seenBatches = batches.count
  let seenDeliveries = deliveries.count
  for number in 0..<5 {
    try "two".write(
      to: scratch.folder.appendingPathComponent("after-\(number).md"), atomically: true,
      encoding: .utf8)
  }
  try await Task.sleep(for: .milliseconds(800))
  #expect(batches.count == seenBatches)
  #expect(deliveries.count == seenDeliveries)
  #expect(try index.entries(includeCleared: true).count == 1)
}

@Test func imageChangeReconcilesItsThought() async throws {
  let scratch = Scratch()
  let store = scratch.store
  let thought = try store.add(NewThought(content: .image(.data(png(side: 8), .png), note: "")))
  let recognizer = FakeRecognizer()
  let deliveries = Deliveries()
  let live = LiveIndex(
    location: scratch.location, index: try scratch.makeIndex(), recognizer: recognizer)
  try live.start { deliveries.record($0) }
  defer { live.stop() }
  #expect(await eventually { recognizer.calls == 1 })

  let image = try #require(store.imageURL(of: thought))
  try png(side: 9).write(to: image, options: .atomic)
  #expect(await eventually { recognizer.calls == 2 })
  #expect(
    await eventually {
      deliveries.failures.isEmpty && deliveries.sawUpdate(of: thought.file.lastPathComponent)
    })
}

@Test func restartListsFilesAddedWhileStopped() async throws {
  let scratch = Scratch()
  let deliveries = Deliveries()
  let index = try scratch.makeIndex()
  let live = LiveIndex(location: scratch.location, index: index, recognizer: nil)
  try live.start { deliveries.record($0) }
  live.stop()
  try "late".write(
    to: scratch.folder.appendingPathComponent("late.md"), atomically: true, encoding: .utf8)
  try live.restart()
  defer { live.stop() }
  #expect(await eventually { deliveries.changes.contains { $0.added == ["late.md"] } })
}

@Test func editToNFCNamedThoughtShowsUpThroughBatch() async throws {
  let scratch = Scratch()
  let composed = "caf\u{E9}-nfc00001.md"
  let decomposed = "cafe\u{301}-nfc00001.md"
  let url = scratch.folder.appendingPathComponent(decomposed)
  try "hello".write(to: url, atomically: false, encoding: .utf8)
  try #require(
    rename(scratch.folder.path + "/" + decomposed, scratch.folder.path + "/" + composed) == 0)
  let listed = try FileManager.default.contentsOfDirectory(atPath: scratch.folder.path)
  try #require(listed.count == 1 && listed[0].utf8.elementsEqual(composed.utf8))

  let deliveries = Deliveries()
  let index = try scratch.makeIndex()
  let live = LiveIndex(location: scratch.location, index: index, recognizer: nil)
  try live.start { deliveries.record($0) }
  defer { live.stop() }
  #expect(await eventually { deliveries.count > 0 })

  try "hello zebra".write(
    to: scratch.folder.appendingPathComponent(composed), atomically: false, encoding: .utf8)
  #expect(await eventually { (try? index.search("zebra").count) == 1 })
  #expect(await eventually { deliveries.sawUpdate(of: composed) })
}

@Test func missingFolderIsReportedAsUnavailable() async throws {
  let scratch = Scratch()
  let deliveries = Deliveries()
  let live = LiveIndex(location: scratch.location, index: try scratch.makeIndex(), recognizer: nil)
  try live.start { deliveries.record($0) }
  defer { live.stop() }
  try FileManager.default.removeItem(at: scratch.folder)
  #expect(await eventually { !deliveries.failures.isEmpty })
  #expect(
    deliveries.failures.allSatisfy { if case .storageUnavailable = $0 { true } else { false } })
}

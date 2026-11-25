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
    ThoughtStore(
      folder: folder,
      trash: { url in
        try FileManager.default.removeItem(at: url)
        return url
      })
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
  seconds: Double = 20, _ condition: @Sendable () -> Bool
) async -> Bool {
  let deadline = Date().addingTimeInterval(seconds)
  while Date() < deadline {
    if condition() { return true }
    try? await Task.sleep(for: .milliseconds(20))
  }
  return condition()
}

private func writeOutsideFilesUntil(
  _ recognizer: SlowRecognizer, folder: URL, total target: Int, writeCap: Int = 300
) async throws -> Int {
  var written = 0
  while recognizer.total < target && written < writeCap {
    try "outside \(written)".write(
      to: folder.appendingPathComponent("outside-\(written).md"), atomically: true,
      encoding: .utf8)
    written += 1
    try await Task.sleep(for: .milliseconds(100))
  }
  #expect(recognizer.total >= target)
  return written
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

private final class SlowRecognizer: TextRecognizing, Sendable {
  private let seen = Mutex<[String: Int]>([:])
  private let delay: TimeInterval
  private let gate: Mutex<(held: Bool, permits: Int, granted: Int)>

  init(delay: TimeInterval, holdsAfterFirst: Bool = false) {
    self.delay = delay
    self.gate = Mutex((holdsAfterFirst, 0, 0))
  }

  func release() {
    gate.withLock { $0.held = false }
  }

  func grantIfIdle(limit: Int) -> Bool {
    gate.withLock { state in
      guard state.permits == 0 else { return true }
      guard state.granted < limit else { return false }
      state.permits += 1
      state.granted += 1
      return true
    }
  }

  private func mayProceed() -> Bool {
    gate.withLock { state in
      if !state.held { return true }
      if state.permits > 0 {
        state.permits -= 1
        return true
      }
      return false
    }
  }

  var total: Int { seen.withLock { $0.values.reduce(0, +) } }
  var mostPerImage: Int { seen.withLock { $0.values.max() ?? 0 } }

  var names: Set<String> { seen.withLock { Set($0.keys) } }

  func text(in image: URL) throws -> String {
    Thread.sleep(forTimeInterval: delay)
    while total >= 1 && !mayProceed() {
      Thread.sleep(forTimeInterval: 0.005)
    }
    seen.withLock { $0[image.lastPathComponent, default: 0] += 1 }
    return "invoice"
  }
}

@Test func stopCancelsRecognitionBetweenBatches() async throws {
  let scratch = Scratch()
  let store = scratch.store
  let count = 60
  let delay = 0.04
  for _ in 0..<count {
    _ = try store.add(NewThought(content: .image(.data(png(side: 8), .png), note: "")))
  }
  let recognizer = SlowRecognizer(delay: delay, holdsAfterFirst: true)
  let live = LiveIndex(
    location: scratch.location, index: try scratch.makeIndex(), recognizer: recognizer)
  try live.start { _ in }
  defer { recognizer.release() }
  #expect(await eventually { recognizer.total >= 1 })

  let stopping = Task.detached { live.stop() }
  try await Task.sleep(for: .milliseconds(100))
  recognizer.release()
  await stopping.value
  let stopped = recognizer.total
  #expect(stopped < count)
  try await Task.sleep(for: .milliseconds(300))
  #expect(recognizer.total == stopped)

  try live.restart()
  defer { live.stop() }
  #expect(await eventually(seconds: 30) { recognizer.total >= count })
  try await Task.sleep(for: .milliseconds(300))
  #expect(recognizer.total == count)
  #expect(recognizer.mostPerImage == 1)
}

@Test func stopOfAnotherIndexFromOnChangeWaitsForItsBatch() async throws {
  let first = Scratch()
  let second = Scratch()
  for _ in 0..<24 {
    _ = try second.store.add(NewThought(content: .image(.data(png(side: 8), .png), note: "")))
  }
  let recognizer = SlowRecognizer(delay: 0.1)
  let other = LiveIndex(
    location: second.location, index: try second.makeIndex(), recognizer: recognizer)
  try other.start { _ in }
  #expect(await eventually { recognizer.total >= 1 })

  let atReturn = Mutex<Int?>(nil)
  let live = LiveIndex(location: first.location, index: try first.makeIndex(), recognizer: nil)
  try live.start { _ in
    other.stop()
    atReturn.withLock { $0 = recognizer.total }
  }
  defer { live.stop() }
  try "trigger".write(
    to: first.folder.appendingPathComponent("trigger.md"), atomically: true, encoding: .utf8)
  #expect(await eventually { atReturn.withLock { $0 } != nil })
  let stopped = try #require(atReturn.withLock { $0 })
  try await Task.sleep(for: .milliseconds(1200))
  #expect(recognizer.total == stopped)
}

@Test func outsideChangeArrivesDuringRecognition() async throws {
  let scratch = Scratch()
  let count = 60
  let delay = 0.04
  for _ in 0..<count {
    _ = try scratch.store.add(NewThought(content: .image(.data(png(side: 8), .png), note: "")))
  }
  let recognizer = SlowRecognizer(delay: delay, holdsAfterFirst: true)
  let deliveries = Deliveries()
  let live = LiveIndex(
    location: scratch.location, index: try scratch.makeIndex(), recognizer: recognizer)
  try live.start { deliveries.record($0) }
  defer { live.stop() }
  defer { recognizer.release() }
  #expect(await eventually { recognizer.total >= 1 })

  try "from the command line".write(
    to: scratch.folder.appendingPathComponent("outside.md"), atomically: true, encoding: .utf8)
  let permitLimit = 30
  let arrived = await eventually(seconds: 60) {
    guard recognizer.grantIfIdle(limit: permitLimit) else { return true }
    return deliveries.changes.contains { $0.added.contains("outside.md") }
  }
  #expect(arrived)
  #expect(deliveries.changes.contains { $0.added.contains("outside.md") })
  #expect(recognizer.total <= permitLimit + 1)
  #expect(recognizer.total < count)
  recognizer.release()

  #expect(await eventually(seconds: 30) { recognizer.total >= count })
  try await Task.sleep(for: .milliseconds(300))
  #expect(recognizer.total == count)
  #expect(recognizer.mostPerImage == 1)
}

private func checkNewImagesArriveBeforeTheirRecognition(gap: Duration?) async throws {
  let scratch = Scratch()
  for _ in 0..<30 {
    _ = try scratch.store.add(NewThought(content: .image(.data(png(side: 8), .png), note: "")))
  }
  let recognizer = SlowRecognizer(delay: 0.04)
  let fresh = Mutex<[String: String]>([:])
  let recognizedAtArrival = Mutex<[String: Set<String>]>([:])
  let live = LiveIndex(
    location: scratch.location, index: try scratch.makeIndex(), recognizer: recognizer)
  try live.start { result in
    guard case .success(let changes) = result else { return }
    let snapshot = recognizer.names
    for name in changes.added { recognizedAtArrival.withLock { $0[name] = snapshot } }
  }
  defer { live.stop() }
  #expect(await eventually { recognizer.total >= 1 })

  for _ in 0..<16 {
    let thought = try scratch.store.add(
      NewThought(content: .image(.data(png(side: 9), .png), note: "")))
    let image = try #require(scratch.store.imageURL(of: thought)).lastPathComponent
    fresh.withLock { $0[thought.file.lastPathComponent] = image }
    if let gap { try await Task.sleep(for: gap) }
  }
  let expected = fresh.withLock { $0 }
  #expect(
    await eventually {
      Set(expected.keys).isSubset(of: Set(recognizedAtArrival.withLock { $0.keys }))
    })
  let early = recognizedAtArrival.withLock { arrivals in
    expected.filter { arrivals[$0.key]?.contains($0.value) == true }.count
  }
  #expect(early == 0)
  #expect(await eventually(seconds: 30) { recognizer.total >= 46 })
  try await Task.sleep(for: .milliseconds(300))
  #expect(recognizer.total == 46)
  #expect(recognizer.mostPerImage == 1)
}

@Test func newImagesArriveBeforeTheirRecognition() async throws {
  try await checkNewImagesArriveBeforeTheirRecognition(gap: nil)
}

@Test func spacedNewImagesArriveBeforeTheirRecognition() async throws {
  try await checkNewImagesArriveBeforeTheirRecognition(gap: .milliseconds(40))
}

@Test func steadyOutsideWritesDoNotStarveOrRewrite() async throws {
  let scratch = Scratch()
  let count = 120
  var imageThoughts: Set<String> = []
  for _ in 0..<count {
    let thought = try scratch.store.add(
      NewThought(content: .image(.data(png(side: 8), .png), note: "")))
    imageThoughts.insert(thought.file.lastPathComponent)
  }
  let recognizer = SlowRecognizer(delay: 0.02)
  let deliveries = Deliveries()
  let live = LiveIndex(
    location: scratch.location, index: try scratch.makeIndex(), recognizer: recognizer)
  try live.start { deliveries.record($0) }
  defer { live.stop() }
  #expect(await eventually { recognizer.total >= 1 })

  let written = try await writeOutsideFilesUntil(
    recognizer, folder: scratch.folder, total: 24)

  #expect(await eventually(seconds: 20) { recognizer.total >= count })
  try await Task.sleep(for: .milliseconds(400))
  #expect(recognizer.total == count)
  #expect(recognizer.mostPerImage == 1)
  #expect(
    await eventually(seconds: 20) {
      deliveries.changes.flatMap(\.added).filter { $0.hasPrefix("outside-") }.count >= written
    })

  let updated = deliveries.changes.flatMap(\.updated)
  #expect(Set(updated).count == updated.count)
  #expect(Set(updated) == imageThoughts)
  let added = deliveries.changes.flatMap(\.added)
  #expect(added.filter { $0.hasPrefix("outside-") }.count == written)
}

@Test func slowHandlerDoesNotStarveRecognition() async throws {
  let scratch = Scratch()
  let count = 200
  for _ in 0..<count {
    _ = try scratch.store.add(NewThought(content: .image(.data(png(side: 8), .png), note: "")))
  }
  let recognizer = SlowRecognizer(delay: 0.01)
  let live = LiveIndex(
    location: scratch.location, index: try scratch.makeIndex(), recognizer: recognizer)
  try live.start { _ in Thread.sleep(forTimeInterval: 0.3) }
  defer { live.stop() }
  #expect(await eventually(seconds: 30) { recognizer.total >= 1 })

  let before = recognizer.total
  for number in 0..<60 {
    try "outside \(number)".write(
      to: scratch.folder.appendingPathComponent("outside-\(number).md"), atomically: true,
      encoding: .utf8)
    try await Task.sleep(for: .milliseconds(100))
  }
  #expect(await eventually(seconds: 30) { recognizer.total - before >= 24 })

  #expect(await eventually(seconds: 30) { recognizer.total >= count })
  try await Task.sleep(for: .milliseconds(500))
  #expect(recognizer.total == count)
  #expect(recognizer.mostPerImage == 1)
}

@Test func changesIndexedByAnotherProcessReachOnChange() async throws {
  let scratch = Scratch()
  let store = scratch.store
  let doomed = try store.add(NewThought(content: .text("doomed")))
  let index = try scratch.makeIndex()
  let other = IndexSync(store: store, index: index, recognizer: nil)
  _ = try other.reconcile(nil)
  let deliveries = Deliveries()
  let live = LiveIndex(location: scratch.location, index: index, recognizer: nil)
  try live.start { deliveries.record($0) }
  defer { live.stop() }
  try await Task.sleep(for: .milliseconds(100))

  let added = try store.add(NewThought(content: .text("from the tool")))
  _ = try other.reconcile([added.file])
  #expect(
    await eventually {
      deliveries.changes.contains {
        ($0.added + $0.updated).contains(added.file.lastPathComponent)
      }
    })

  try FileManager.default.removeItem(at: doomed.file)
  _ = try other.reconcile([doomed.file])
  #expect(
    await eventually {
      deliveries.changes.contains { $0.removed.contains(doomed.file.lastPathComponent) }
    })
  #expect(deliveries.failures.isEmpty)
}

@Test func eventForUnchangedRowDeliversNoUpdate() async throws {
  let scratch = Scratch()
  let thought = try scratch.store.add(NewThought(content: .text("kept")))
  let name = thought.file.lastPathComponent
  let deliveries = Deliveries()
  let live = LiveIndex(location: scratch.location, index: try scratch.makeIndex(), recognizer: nil)
  try live.start { deliveries.record($0) }
  defer { live.stop() }
  #expect(await eventually { deliveries.changes.contains { $0.added.contains(name) } })

  let tag = Array("kept".utf8)
  #expect(setxattr(thought.file.path, "thoughts.test", tag, tag.count, 0, 0) == 0)
  try "sentinel".write(
    to: scratch.folder.appendingPathComponent("sentinel.md"), atomically: false, encoding: .utf8)
  #expect(await eventually { deliveries.changes.contains { $0.added.contains("sentinel.md") } })
  #expect(!deliveries.sawUpdate(of: name))
  #expect(deliveries.failures.isEmpty)
}

import Foundation
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers

@testable import ThoughtsCore

private final class Counter: Sendable {
  let value = Mutex(0)
}

private final class Rig: @unchecked Sendable {
  let scratch: URL
  let folder: URL
  let bin: URL
  let store: ThoughtStore

  struct Refused: Error {}

  private let moves = Counter()

  init(failingOn failing: Int? = nil) throws {
    scratch = FileManager.default.temporaryDirectory
      .appendingPathComponent("restore-tests-\(UUID().uuidString)")
    folder = scratch.appendingPathComponent("Thoughts")
    bin = scratch.appendingPathComponent("Trash")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    let bin = bin
    let moves = moves
    store = ThoughtStore(
      folder: folder,
      trash: { url in
        let count = moves.value.withLock {
          $0 += 1
          return $0
        }
        if count == failing { throw Refused() }
        let landed = bin.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: landed)
        return landed
      })
  }

  deinit {
    try? FileManager.default.removeItem(at: scratch)
  }

  private var added = 0

  func text(_ text: String) throws -> Thought {
    added += 1
    let created = Date(timeIntervalSince1970: 1_795_000_000 + Double(added * 60))
    return try store.add(NewThought(content: .text(text), source: nil, created: created))
  }

  func screenshot(note: String) throws -> Thought {
    let context = CGContext(
      data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
      data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return try store.add(
      NewThought(
        content: .image(.data(data as Data, .png), note: note), source: nil, created: Date())
    )
  }

  func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }
}

@Test func deleteReportsWhereEveryFileLanded() throws {
  let rig = try Rig()
  let shot = try rig.screenshot(note: "a note")
  let image = try #require(rig.store.imageURL(of: shot))
  let moved = try rig.store.delete([shot.id])
  #expect(moved.map(\.original) == [shot.file, image])
  #expect(moved.allSatisfy { rig.exists($0.trashed) && !rig.exists($0.original) })
}

@Test func restorePutsBothFilesOfAnImageThoughtBack() throws {
  let rig = try Rig()
  let shot = try rig.screenshot(note: "a note")
  let image = try #require(rig.store.imageURL(of: shot))
  let moved = try rig.store.delete([shot.id])
  try rig.store.restore(moved)
  #expect(rig.exists(shot.file) && rig.exists(image))
  #expect(moved.allSatisfy { !rig.exists($0.trashed) })
  let back = try rig.store.thought(matching: shot.id.rawValue)
  #expect(back.content == shot.content)
}

@Test func redoAfterRestoreTrashesTheSameFilesAgain() throws {
  let rig = try Rig()
  let first = try rig.text("one")
  let second = try rig.text("two")
  let moved = try rig.store.delete([first.id, second.id])
  try rig.store.restore(moved)
  let again = try rig.store.trashFiles(moved.map(\.original))
  #expect(again.map(\.original) == moved.map(\.original))
  #expect(again.allSatisfy { rig.exists($0.trashed) && !rig.exists($0.original) })
  try rig.store.restore(again)
  #expect(try rig.store.entries().count == 2)
}

@Test func restoreWithAFileGoneFromTheTrashMovesNothing() throws {
  let rig = try Rig()
  let shot = try rig.screenshot(note: "a note")
  let moved = try rig.store.delete([shot.id])
  try FileManager.default.removeItem(at: moved[1].trashed)
  #expect(throws: RestoreError.notInTrash) { try rig.store.restore(moved) }
  #expect(rig.exists(moved[0].trashed))
  #expect(!rig.exists(moved[0].original))
}

@Test func restoreWithTheNameTakenMovesNothingAndKeepsTheNewFile() throws {
  let rig = try Rig()
  let shot = try rig.screenshot(note: "a note")
  let moved = try rig.store.delete([shot.id])
  try Data("newer".utf8).write(to: moved[1].original)
  #expect(throws: RestoreError.nameTaken) { try rig.store.restore(moved) }
  #expect(moved.allSatisfy { rig.exists($0.trashed) })
  #expect(!rig.exists(moved[0].original))
  #expect(try Data(contentsOf: moved[1].original) == Data("newer".utf8))
}

@Test func trashingAFileThatIsGoneReportsItChanged() throws {
  let rig = try Rig()
  let thought = try rig.text("one")
  try FileManager.default.removeItem(at: thought.file)
  #expect(throws: RestoreError.changed) { try rig.store.trashFiles([thought.file]) }
}

@Test func amendRestoresMarksWithTheOriginalDate() throws {
  let rig = try Rig()
  let thought = try rig.text("one")
  let doneAt = Date(timeIntervalSince1970: 1_795_000_000)
  let done = try rig.store.setDone(true, for: thought.id, at: doneAt)
  let cleared = try #require(try rig.store.clearingDone().first)
  #expect(cleared.cleared)
  let back = try rig.store.amend([
    Amendment(
      id: cleared.id, file: cleared.file, expected: cleared.version,
      change: .mark(ThoughtMark(done: done.done, cleared: false)))
  ])
  #expect(back.first?.done == done.done)
  #expect(back.first?.cleared == false)
  let stored = try rig.store.thought(matching: thought.id.rawValue)
  #expect(stored.done == done.done && !stored.cleared)
}

@Test func amendChangesNothingWhenOneFileChangedSince() throws {
  let rig = try Rig()
  let first = try rig.text("one")
  let second = try rig.text("two")
  let firstDone = try rig.store.setDone(true, for: first.id, at: Date())
  let secondDone = try rig.store.setDone(true, for: second.id, at: Date())
  _ = try rig.store.setText("two, edited", of: second.id, expected: secondDone.version)
  let amendments = [firstDone, secondDone].map {
    Amendment(
      id: $0.id, file: $0.file, expected: $0.version,
      change: .mark(ThoughtMark(done: nil, cleared: false)))
  }
  #expect(throws: ThoughtsError.changedOnDisk(second.id)) { try rig.store.amend(amendments) }
  #expect(try rig.store.thought(matching: first.id.rawValue).done != nil)
  #expect(try rig.store.thought(matching: second.id.rawValue).content == .text("two, edited"))
}

@Test func amendOfAFileThatIsGoneReportsItDeleted() throws {
  let rig = try Rig()
  let thought = try rig.text("one")
  try FileManager.default.removeItem(at: thought.file)
  #expect(throws: ThoughtsError.deletedOnDisk(thought.id)) {
    try rig.store.amend([
      Amendment(
        id: thought.id, file: thought.file, expected: thought.version, change: .text("two"))
    ])
  }
}

@Test func amendTextOnAnImageThoughtChangesItsNote() throws {
  let rig = try Rig()
  let shot = try rig.screenshot(note: "before")
  let edited = try #require(
    try rig.store.amend([
      Amendment(id: shot.id, file: shot.file, expected: shot.version, change: .text("after"))
    ]).first)
  guard case .image(_, let note) = edited.content else {
    Issue.record("expected an image thought")
    return
  }
  #expect(note == "after")
}

@Test func deleteThatFailsPartwayStillReportsWhatLanded() throws {
  let rig = try Rig(failingOn: 2)
  let first = try rig.text("one")
  let second = try rig.text("two")
  let third = try rig.text("three")
  var landed: [TrashedFile] = []
  #expect(throws: ThoughtsError.self) {
    try rig.store.delete([first.id, second.id, third.id], landing: &landed)
  }
  #expect(landed.map(\.original) == [first.file])
  #expect(!rig.exists(first.file) && rig.exists(second.file) && rig.exists(third.file))
  try rig.store.restore(landed)
  #expect(try rig.store.entries().count == 3)
}

@Test func clearingDoneThatFailsPartwayStillReportsWhatLanded() throws {
  let rig = try Rig()
  let first = try rig.text("one")
  let second = try rig.text("two")
  let third = try rig.text("three")
  for thought in [first, second, third] {
    _ = try rig.store.setDone(true, for: thought.id, at: Date())
  }
  try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: second.file.path)
  defer {
    try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: second.file.path)
  }
  var landed: [Thought] = []
  #expect(throws: ThoughtsError.self) { try rig.store.clearingDone(landing: &landed) }
  #expect(landed.map(\.id) == [first.id])
  #expect(landed.allSatisfy { $0.cleared })
  let stored = try rig.store.entries().compactMap { entry -> Thought? in
    if case .thought(let thought) = entry { thought } else { nil }
  }
  #expect(stored.filter(\.cleared).map(\.id) == [first.id])
}

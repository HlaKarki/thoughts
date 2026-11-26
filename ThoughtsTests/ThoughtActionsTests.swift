import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

final class FakeTrash: @unchecked Sendable {
  private let lock = NSLock()
  private var urls: [URL] = []
  private var moves = 0
  let folder: URL
  let failingOn: Int?

  struct Refused: LocalizedError {
    var errorDescription: String? { "The Trash is full" }
  }

  init(folder: URL, failingOn: Int? = nil) {
    self.folder = folder
    self.failingOn = failingOn
  }

  func move(_ url: URL) throws -> URL {
    lock.lock()
    moves += 1
    let refuse = moves == failingOn
    lock.unlock()
    if refuse { throw Refused() }
    let slot = folder.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: slot, withIntermediateDirectories: true)
    let landed = slot.appendingPathComponent(url.lastPathComponent)
    try FileManager.default.moveItem(at: url, to: landed)
    lock.lock()
    urls.append(url)
    lock.unlock()
    return landed
  }

  var all: [URL] {
    lock.lock()
    defer { lock.unlock() }
    return urls
  }
}

@MainActor
final class OpenerLog {
  var urls: [URL] = []
  var apps: [String] = []
  var revealed: [[URL]] = []
  var knownApps: Set<String> = []

  var opener: SourceOpener {
    SourceOpener(
      openURL: { [self] in
        urls.append($0)
        return true
      },
      launchApp: { [self] in
        apps.append($0)
        return knownApps.contains($0)
      },
      reveal: { [self] in revealed.append($0) })
  }
}

@MainActor
@Suite(.throwaway)
struct ThoughtActionsTests {
  struct Rig {
    let fixture: ListFixture
    let actions: ThoughtActions
    let log: OpenerLog
    let board: NSPasteboard
    let trashed: FakeTrash
  }

  static func rig() throws -> Rig {
    let fixture = try ListFixture()
    let log = OpenerLog()
    let board = Throwaway.pasteboard()
    let trashed = FakeTrash(folder: fixture.root.appendingPathComponent("Trash"))
    let undoManager = UndoManager()
    undoManager.groupsByEvent = false
    let actions = ThoughtActions(
      list: fixture.model, location: fixture.location,
      pasteboard: PasteboardWriter(pasteboard: board), opener: log.opener,
      trash: { try trashed.move($0) }, undoManager: undoManager,
      now: { ListFixture.now.addingTimeInterval(3600) })
    return Rig(fixture: fixture, actions: actions, log: log, board: board, trashed: trashed)
  }

  @Test func doneMarksAllOnAMixedSelectionAndClearsOnAnAllDoneOne() async throws {
    let rig = try Self.rig()
    try rig.fixture.addText("one", daysAgo: 3, done: true)
    try rig.fixture.addText("two", daysAgo: 2)
    try rig.fixture.reload()
    rig.fixture.model.selection = rig.fixture.model.visible.map(\.fileName)
    func doneStates() throws -> [Bool] {
      try rig.fixture.store.entries().compactMap(\.thought).map { $0.done != nil }
    }
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    #expect(try doneStates() == [true, true])
    try rig.fixture.reload()
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    #expect(try doneStates() == [false, false])
  }

  @Test func doneLeavesAlreadyDoneThoughtsUntouched() async throws {
    let rig = try Self.rig()
    let finished = try rig.fixture.addText("one", daysAgo: 3, done: true)
    let open = try rig.fixture.addText("two", daysAgo: 2)
    try rig.fixture.reload()
    rig.fixture.model.selection = rig.fixture.model.visible.map(\.fileName)
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    let stored = try rig.fixture.store.entries().compactMap(\.thought)
    let byID = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
    #expect(byID[finished.id]?.done == ListFixture.now)
    #expect(byID[open.id]?.done == ListFixture.now.addingTimeInterval(3600))
  }

  @Test func doneDecidesFromPendingStateBeforeTheListRefreshes() async throws {
    let rig = try Self.rig()
    try rig.fixture.addText("one", daysAgo: 3, done: true)
    try rig.fixture.addText("two", daysAgo: 2)
    try rig.fixture.reload()
    rig.fixture.model.selection = rig.fixture.model.visible.map(\.fileName)
    rig.actions.perform(.toggleDone)
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    let states = try rig.fixture.store.entries().compactMap(\.thought).map { $0.done != nil }
    #expect(states == [false, false])
    try rig.fixture.reload()
    #expect(rig.fixture.model.pendingDone.isEmpty)
  }

  @Test func repeatedDeletesWalkPastThePendingRows() async throws {
    let rig = try Self.rig()
    let oldest = try rig.fixture.addText("x", daysAgo: 4)
    let middle = try rig.fixture.addText("y", daysAgo: 3)
    let newest = try rig.fixture.addText("z", daysAgo: 2)
    try rig.fixture.reload()
    rig.fixture.model.select(newest.file.lastPathComponent, extend: false)
    rig.actions.perform(.delete)
    #expect(rig.fixture.model.selection == [middle.file.lastPathComponent])
    rig.fixture.model.load()
    #expect(
      rig.fixture.model.visible.map(\.fileName) == [
        oldest.file.lastPathComponent, middle.file.lastPathComponent,
      ])
    rig.actions.perform(.delete)
    #expect(rig.fixture.model.selection == [oldest.file.lastPathComponent])
    await rig.actions.pending?.value
    #expect(
      Set(rig.trashed.all.map(\.lastPathComponent))
        == [newest.file.lastPathComponent, middle.file.lastPathComponent])
    try rig.fixture.reload()
    #expect(rig.fixture.model.pendingRemoval.isEmpty)
    #expect(rig.fixture.model.visible.map(\.fileName) == [oldest.file.lastPathComponent])
    #expect(rig.fixture.model.selection == [oldest.file.lastPathComponent])
  }

  @Test func deleteTrashesTheFilesAndSelectsTheNeighbor() async throws {
    let rig = try Self.rig()
    try rig.fixture.addText("older", daysAgo: 4)
    let shot = try rig.fixture.addScreenshot(note: "middle", daysAgo: 3)
    let newer = try rig.fixture.addText("newer", daysAgo: 2)
    try rig.fixture.reload()
    rig.fixture.model.select(shot.file.lastPathComponent, extend: false)
    rig.actions.perform(.delete)
    #expect(rig.fixture.model.selection == [newer.file.lastPathComponent])
    await rig.actions.pending?.value
    let trashed = Set(rig.trashed.all.map(\.lastPathComponent))
    let image = try #require(rig.fixture.store.imageURL(of: shot)).lastPathComponent
    #expect(trashed == [shot.file.lastPathComponent, image])
  }

  @Test func deletingTheLastThoughtReturnsToTheInput() async throws {
    let rig = try Self.rig()
    let only = try rig.fixture.addText("only", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.select(only.file.lastPathComponent, extend: false)
    rig.actions.perform(.delete)
    await rig.actions.pending?.value
    #expect(rig.fixture.model.selection.isEmpty)
    #expect(rig.fixture.model.focus == .input)
  }

  @Test func copyWritesTextThenAMarkdownListThenPaths() throws {
    let rig = try Self.rig()
    let text = try rig.fixture.addText("Ask the team", daysAgo: 3)
    let shot = try rig.fixture.addScreenshot(note: "Reword", daysAgo: 2)
    try rig.fixture.reload()
    let names = rig.fixture.model.visible.map(\.fileName)
    rig.fixture.model.select(text.file.lastPathComponent, extend: false)
    rig.actions.perform(.copy)
    #expect(rig.board.string(forType: .string) == "Ask the team")
    rig.fixture.model.selection = names
    rig.actions.perform(.copy)
    let image = try #require(rig.fixture.store.imageURL(of: shot)).path
    #expect(rig.board.string(forType: .string) == "- Ask the team\n- Reword\n  \(image)")
    rig.actions.perform(.copyPath)
    #expect(rig.board.string(forType: .string) == "\(text.file.path)\n\(image)")
  }

  @Test func openOriginalTriesTheURLThenTheAppThenTheFile() throws {
    let rig = try Self.rig()
    let page = try #require(URL(string: "https://example.com/page"))
    let original = rig.fixture.root.appendingPathComponent("original.txt")
    try Data("x".utf8).write(to: original)
    let withURL = try rig.fixture.addText(
      "a", daysAgo: 4, source: Source(bundleID: "com.example.browser", url: page))
    let withApp = try rig.fixture.addText(
      "b", daysAgo: 3, source: Source(bundleID: "com.example.editor"))
    let withFile = try rig.fixture.addText(
      "c", daysAgo: 2, source: Source(bundleID: "com.example.gone", file: original.path))
    try rig.fixture.reload()
    rig.log.knownApps = ["com.example.editor"]
    for thought in [withURL, withApp, withFile] {
      rig.fixture.model.select(thought.file.lastPathComponent, extend: false)
      rig.actions.perform(.openSource)
    }
    #expect(rig.log.urls == [page])
    #expect(rig.log.apps == ["com.example.editor", "com.example.gone"])
    #expect(rig.log.revealed == [[original]])
  }

  @Test func showInFinderRevealsTheImageForAScreenshot() throws {
    let rig = try Self.rig()
    let text = try rig.fixture.addText("plain", daysAgo: 3)
    let shot = try rig.fixture.addScreenshot(note: "", daysAgo: 2)
    try rig.fixture.reload()
    rig.fixture.model.selection = rig.fixture.model.visible.map(\.fileName)
    rig.actions.perform(.showInFinder)
    let image = try #require(rig.fixture.store.imageURL(of: shot))
    #expect(rig.log.revealed == [[text.file, image]])
  }
}

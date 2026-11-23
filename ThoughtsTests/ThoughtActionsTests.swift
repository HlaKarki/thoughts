import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

final class Recorder: @unchecked Sendable {
  private let lock = NSLock()
  private var urls: [URL] = []

  func add(_ url: URL) {
    lock.lock()
    urls.append(url)
    lock.unlock()
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
struct ThoughtActionsTests {
  struct Rig {
    let fixture: ListFixture
    let actions: ThoughtActions
    let log: OpenerLog
    let board: NSPasteboard
    let trashed: Recorder
  }

  static func rig() throws -> Rig {
    let fixture = try ListFixture()
    let log = OpenerLog()
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    let trashed = Recorder()
    let actions = ThoughtActions(
      list: fixture.model, location: fixture.location,
      pasteboard: PasteboardWriter(pasteboard: board), opener: log.opener,
      trash: { trashed.add($0) }, now: { ListFixture.now })
    return Rig(fixture: fixture, actions: actions, log: log, board: board, trashed: trashed)
  }

  @Test func doneMarksAllOnAMixedSelectionAndClearsOnAnAllDoneOne() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
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

  @Test func deleteTrashesTheFilesAndSelectsTheNeighbor() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
    let text = try rig.fixture.addText("plain", daysAgo: 3)
    let shot = try rig.fixture.addScreenshot(note: "", daysAgo: 2)
    try rig.fixture.reload()
    rig.fixture.model.selection = rig.fixture.model.visible.map(\.fileName)
    rig.actions.perform(.showInFinder)
    let image = try #require(rig.fixture.store.imageURL(of: shot))
    #expect(rig.log.revealed == [[text.file, image]])
  }
}

import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

actor SleepGate {
  private(set) var requested: [Duration] = []
  private var waiting: [Int: CheckedContinuation<Void, any Error>] = [:]

  func wait(_ duration: Duration) async throws {
    let id = requested.count
    requested.append(duration)
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { waiting[id] = $0 }
    } onCancel: {
      Task { await self.cancel(id) }
    }
  }

  func fire(_ id: Int) {
    waiting.removeValue(forKey: id)?.resume()
  }

  private func cancel(_ id: Int) {
    waiting.removeValue(forKey: id)?.resume(throwing: CancellationError())
  }

  func requests() -> [Duration] { requested }
}

@MainActor
enum Eventually {
  static func hold(_ condition: @MainActor () async -> Bool) async -> Bool {
    for _ in 0..<5000 {
      if await condition() { return true }
      await Task.yield()
    }
    return false
  }
}

@MainActor
struct FeedbackTests {
  static func rig() throws -> (fixture: ListFixture, gate: SleepGate) {
    let gate = SleepGate()
    let fixture = try ListFixture(feedbackDelay: { try await gate.wait($0) })
    fixture.model.panelDidShow()
    return (fixture, gate)
  }

  static func armed(_ gate: SleepGate, _ count: Int) async -> Bool {
    await Eventually.hold { await gate.requests().count >= count }
  }

  @Test func aConfirmationLastsOneAndAHalfSeconds() async throws {
    let (fixture, gate) = try Self.rig()
    let model = fixture.model
    model.confirm("Copied")
    #expect(model.feedback?.kind == .confirmation)
    #expect(model.feedback?.text == "Copied")
    #expect(await Self.armed(gate, 1))
    #expect(await gate.requests() == [.milliseconds(1500)])
    #expect(model.feedback != nil)
    await gate.fire(0)
    #expect(await Eventually.hold { model.feedback == nil })
  }

  @Test func aMessageLastsFourSeconds() async throws {
    let (fixture, gate) = try Self.rig()
    let model = fixture.model
    model.tell("Select a thought first")
    #expect(model.feedback?.kind == .message)
    #expect(await Self.armed(gate, 1))
    #expect(await gate.requests() == [.seconds(4)])
    await gate.fire(0)
    #expect(await Eventually.hold { model.feedback == nil })
  }

  @Test func aNewResultReplacesTheOldOneAndRestartsTheTimer() async throws {
    let (fixture, gate) = try Self.rig()
    let model = fixture.model
    model.tell("First")
    #expect(await Self.armed(gate, 1))
    model.confirm("Second")
    #expect(await Self.armed(gate, 2))
    #expect(await gate.requests() == [.seconds(4), .milliseconds(1500)])
    #expect(model.feedback?.text == "Second")
    #expect(model.feedback?.kind == .confirmation)
    await gate.fire(0)
    for _ in 0..<50 { await Task.yield() }
    #expect(model.feedback?.text == "Second")
    await gate.fire(1)
    #expect(await Eventually.hold { model.feedback == nil })
  }

  @Test func theSameTextTwiceIsTwoResults() async throws {
    let (fixture, gate) = try Self.rig()
    let model = fixture.model
    model.confirm("Copied")
    let first = try #require(model.feedback?.id)
    #expect(await Self.armed(gate, 1))
    model.confirm("Copied")
    #expect(model.feedback?.id != first)
    #expect(await Self.armed(gate, 2))
  }

  @Test func aFocusChangeEndsItEarly() async throws {
    let (fixture, gate) = try Self.rig()
    let model = fixture.model
    model.confirm("Copied")
    #expect(await Self.armed(gate, 1))
    model.focus = .search
    #expect(model.feedback == nil)
    model.tell("Select a thought first")
    model.focus = .list
    #expect(model.feedback == nil)
  }

  @Test func theSameFocusDoesNotEndIt() async throws {
    let (fixture, _) = try Self.rig()
    let model = fixture.model
    model.confirm("Copied")
    model.focus = .input
    #expect(model.feedback?.text == "Copied")
  }

  @Test func hidingThePanelDropsAConfirmationAndKeepsAMessage() async throws {
    let (fixture, gate) = try Self.rig()
    let model = fixture.model
    model.confirm("Copied")
    model.panelDidHide()
    #expect(model.feedback == nil)
    model.tell("The clipboard changed")
    model.panelDidHide()
    #expect(model.feedback?.text == "The clipboard changed")
    model.confirm("Copied")
    #expect(model.feedback?.kind == .message)
    #expect(await gate.requests().count <= 2)
    model.panelDidShow()
    #expect(await Self.armed(gate, 2))
  }

  @Test func aMessageRaisedWhileHiddenStartsItsTimerWhenTheListOpens() async throws {
    let gate = SleepGate()
    let fixture = try ListFixture(feedbackDelay: { try await gate.wait($0) })
    fixture.model.tell("The folder is unavailable")
    for _ in 0..<50 { await Task.yield() }
    #expect(await gate.requests().isEmpty)
    fixture.model.panelDidShow()
    #expect(await Self.armed(gate, 1))
    #expect(await gate.requests() == [.seconds(4)])
  }

  @Test func theStorageProblemStaysBehindTransientResults() async throws {
    let (fixture, gate) = try Self.rig()
    let model = fixture.model
    try FileManager.default.removeItem(at: fixture.folder)
    model.receive(.failure(.storageUnavailable("/example/home/Thoughts")))
    #expect(model.shownFeedback?.kind == .message)
    let problem = model.shownFeedback?.text
    model.confirm("Copied")
    #expect(model.shownFeedback?.text == "Copied")
    #expect(await Self.armed(gate, 1))
    await gate.fire(0)
    #expect(await Eventually.hold { model.shownFeedback?.text == problem })
  }
}

@MainActor
struct ActionFeedbackTests {
  static func rig() throws -> (rig: ThoughtActionsTests.Rig, gate: SleepGate) {
    let gate = SleepGate()
    let fixture = try ListFixture(feedbackDelay: { try await gate.wait($0) })
    fixture.model.panelDidShow()
    let log = OpenerLog()
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    let trashed = FakeTrash(folder: fixture.root.appendingPathComponent("Trash"))
    let undoManager = UndoManager()
    undoManager.groupsByEvent = false
    let actions = ThoughtActions(
      list: fixture.model, location: fixture.location,
      pasteboard: PasteboardWriter(pasteboard: board), opener: log.opener,
      trash: { try trashed.move($0) }, undoManager: undoManager, now: { ListFixture.now })
    let rig = ThoughtActionsTests.Rig(
      fixture: fixture, actions: actions, log: log, board: board, trashed: trashed)
    return (rig, gate)
  }

  @Test func copyConfirmsAndPutsTheTextOnTheClipboard() throws {
    let (rig, _) = try Self.rig()
    defer { rig.board.releaseGlobally() }
    let thought = try rig.fixture.addText("call the dentist", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.selection = [thought.file.lastPathComponent]
    rig.actions.perform(.copy)
    #expect(rig.board.string(forType: .string) == "call the dentist")
    #expect(rig.fixture.model.feedback?.kind == .confirmation)
    #expect(rig.fixture.model.feedback?.text == "Copied")
  }

  @Test func copyWithNothingSelectedSaysWhy() throws {
    let (rig, _) = try Self.rig()
    defer { rig.board.releaseGlobally() }
    rig.actions.perform(.copy)
    #expect(rig.fixture.model.feedback?.kind == .message)
    #expect(rig.fixture.model.feedback?.text == "Select a thought first")
  }

  @Test func copyOfAnImageWhoseFileIsGoneSaysSo() async throws {
    let (rig, _) = try Self.rig()
    defer { rig.board.releaseGlobally() }
    let thought = try rig.fixture.addScreenshot(note: "", daysAgo: 1)
    try rig.fixture.reload()
    let image = try #require(rig.fixture.store.imageURL(of: thought))
    try FileManager.default.removeItem(at: image)
    rig.fixture.model.selection = [thought.file.lastPathComponent]
    rig.actions.perform(.copy)
    await rig.actions.pending?.value
    #expect(rig.fixture.model.feedback?.kind == .message)
    #expect(rig.fixture.model.feedback?.text == "That image file isn't there anymore")
  }

  @Test func copyOfAnImageThatCannotBeConvertedSaysItCannotBeRead() async throws {
    let (rig, _) = try Self.rig()
    defer { rig.board.releaseGlobally() }
    let thought = try rig.fixture.addScreenshot(note: "", daysAgo: 1)
    try rig.fixture.reload()
    let image = try #require(rig.fixture.store.imageURL(of: thought))
    try Data("not an image".utf8).write(to: image)
    rig.fixture.model.selection = [thought.file.lastPathComponent]
    rig.actions.perform(.copy)
    await rig.actions.pending?.value
    #expect(rig.fixture.model.feedback?.kind == .message)
    #expect(rig.fixture.model.feedback?.text == "That image file can't be read")
  }

  @Test func showInFinderRevealsWhatExistsAndSaysWhenSomeAreGone() throws {
    let (rig, _) = try Self.rig()
    let kept = try rig.fixture.addText("kept", daysAgo: 2)
    let gone = try rig.fixture.addText("gone", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.selection = [kept.file.lastPathComponent, gone.file.lastPathComponent]
    try FileManager.default.removeItem(at: gone.file)
    rig.actions.perform(.showInFinder)
    #expect(rig.log.revealed.count == 1)
    #expect(rig.log.revealed.first?.map(\.lastPathComponent) == [kept.file.lastPathComponent])
    #expect(rig.fixture.model.feedback?.kind == .message)
    #expect(rig.fixture.model.feedback?.text == "Some of those files aren't there anymore")
  }

  @Test func copyPathConfirmsOnceForOneAndOnceForMany() throws {
    let (rig, _) = try Self.rig()
    defer { rig.board.releaseGlobally() }
    let one = try rig.fixture.addText("one", daysAgo: 2)
    let two = try rig.fixture.addText("two", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.selection = [one.file.lastPathComponent]
    rig.actions.perform(.copyPath)
    #expect(rig.fixture.model.feedback?.text == "Copied the path")
    rig.fixture.model.selection = [one.file.lastPathComponent, two.file.lastPathComponent]
    rig.actions.perform(.copyPath)
    #expect(rig.fixture.model.feedback?.text == "Copied the paths")
    #expect(rig.fixture.model.feedback?.kind == .confirmation)
  }

  @Test func openingTheOriginalWithNoSourceSaysWhy() throws {
    let (rig, _) = try Self.rig()
    let thought = try rig.fixture.addText("no source", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.selection = [thought.file.lastPathComponent]
    rig.actions.perform(.openSource)
    #expect(rig.fixture.model.feedback?.kind == .message)
    #expect(rig.fixture.model.feedback?.text == "This thought has no original to open")
    #expect(rig.log.urls.isEmpty)
    #expect(rig.log.apps.isEmpty)
  }

  @Test func openingTheOriginalOfSeveralThoughtsSaysWhy() throws {
    let (rig, _) = try Self.rig()
    let first = try rig.fixture.addText("a", daysAgo: 2)
    let second = try rig.fixture.addText("b", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.selection = [first.file.lastPathComponent, second.file.lastPathComponent]
    rig.actions.perform(.openSource)
    #expect(rig.fixture.model.feedback?.text == "Select one thought to open its original")
  }

  @Test func openingTheOriginalWithNothingSelectedSaysWhy() throws {
    let (rig, _) = try Self.rig()
    rig.actions.perform(.openSource)
    #expect(rig.fixture.model.feedback?.text == "Select a thought first")
  }

  @Test func openingAnOriginalThatCannotBeOpenedSaysSo() throws {
    let (rig, _) = try Self.rig()
    let thought = try rig.fixture.addText(
      "gone", daysAgo: 1, source: Source(bundleID: "com.example.missing"))
    try rig.fixture.reload()
    rig.fixture.model.selection = [thought.file.lastPathComponent]
    rig.actions.perform(.openSource)
    #expect(rig.fixture.model.feedback?.kind == .message)
    #expect(rig.fixture.model.feedback?.text == "Couldn't open the original. It may have moved.")
  }

  @Test func showInFinderWithNothingSelectedOrMissingFilesSaysWhy() throws {
    let (rig, _) = try Self.rig()
    rig.actions.perform(.showInFinder)
    #expect(rig.fixture.model.feedback?.text == "Select a thought first")
    let thought = try rig.fixture.addScreenshot(note: "", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.selection = [thought.file.lastPathComponent]
    try FileManager.default.removeItem(at: thought.file)
    try FileManager.default.removeItem(at: try #require(rig.fixture.store.imageURL(of: thought)))
    rig.actions.perform(.showInFinder)
    #expect(rig.fixture.model.feedback?.text == "That file isn't there anymore")
    #expect(rig.log.revealed.isEmpty)
  }

  @Test func editPreviewAndTheMenuWithoutOneSelectedThoughtSayWhy() throws {
    let (rig, _) = try Self.rig()
    let model = rig.fixture.model
    let first = try rig.fixture.addText("a", daysAgo: 2)
    let second = try rig.fixture.addText("b", daysAgo: 1)
    try rig.fixture.reload()
    model.perform(.edit)
    #expect(model.feedback?.text == "Select a thought first")
    model.perform(.preview)
    #expect(model.feedback?.text == "Select a thought first")
    model.perform(.actionsMenu)
    #expect(model.feedback?.text == "Select a thought first")
    model.selection = [first.file.lastPathComponent, second.file.lastPathComponent]
    model.perform(.edit)
    #expect(model.feedback?.text == "Select one thought to edit")
    model.perform(.preview)
    #expect(model.feedback?.text == "Select one thought to preview")
    #expect(!model.isPreviewing)
  }

  @Test func deleteAndDoneWithNothingSelectedSayWhy() throws {
    let (rig, _) = try Self.rig()
    rig.actions.perform(.delete)
    #expect(rig.fixture.model.feedback?.text == "Select a thought first")
    rig.fixture.model.focus = .list
    rig.actions.perform(.toggleDone)
    #expect(rig.fixture.model.feedback?.text == "Select a thought first")
  }

  @Test func clearDoneSaysWhenThereIsNothingToClearAndConfirmsWhenThereIs() async throws {
    let (rig, _) = try Self.rig()
    let model = rig.fixture.model
    try rig.fixture.addText("open", daysAgo: 2)
    try rig.fixture.reload()
    rig.actions.perform(.clearDone)
    #expect(await Eventually.hold { model.feedback?.text == "Nothing is marked done" })
    #expect(model.feedback?.kind == .message)
    try rig.fixture.addText("finished", daysAgo: 1, done: true)
    try rig.fixture.reload()
    rig.actions.perform(.clearDone)
    #expect(
      await Eventually.hold {
        model.feedback?.text == "Cleared the done thoughts. Press ⌘Z to bring them back."
      })
    #expect(model.feedback?.kind == .confirmation)
  }

  @Test func addingNothingAndDroppingNothingReadableSayWhy() async throws {
    let (rig, _) = try Self.rig()
    let fixture = rig.fixture
    await fixture.input.submit()
    #expect(fixture.model.feedback?.text == "Type a thought first")
    fixture.model.perform(.type("x"))
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    board.clearContents()
    #expect(!fixture.input.drop(board))
    #expect(fixture.model.feedback?.text == "Drop text, an image or a file")
    #expect(fixture.model.feedback?.kind == .message)
  }
}

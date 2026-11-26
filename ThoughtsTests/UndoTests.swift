import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

final class HoldFlag: @unchecked Sendable {
  var value = false
}

@MainActor
@Suite(.throwaway)
struct UndoTests {
  static let deleteNote = "Moved to the Trash. Press ⌘Z to put it back."
  static let clearNote = "Cleared the done thoughts. Press ⌘Z to bring them back."

  static func rig() throws -> ThoughtActionsTests.Rig {
    try ActionFeedbackTests.rig().rig
  }

  static func names(_ rig: ThoughtActionsTests.Rig) -> [String] {
    rig.fixture.model.visible.map(\.fileName)
  }

  static func stored(_ rig: ThoughtActionsTests.Rig) throws -> [Thought] {
    try rig.fixture.store.entries().compactMap(\.thought)
  }

  @Test func deleteThenUndoThenRedoMovesBothFilesOfAScreenshotBackAndForth() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let older = try rig.fixture.addText("older", daysAgo: 4)
    let shot = try rig.fixture.addScreenshot(note: "middle", daysAgo: 3)
    let newer = try rig.fixture.addText("newer", daysAgo: 2)
    let image = try #require(rig.fixture.store.imageURL(of: shot))
    try rig.fixture.reload()
    model.select(shot.file.lastPathComponent, extend: false)
    rig.actions.perform(.delete)
    await rig.actions.pending?.value
    #expect(model.feedback?.text == Self.deleteNote)
    #expect(model.feedback?.kind == .confirmation)
    #expect(!FileManager.default.fileExists(atPath: shot.file.path))
    #expect(!FileManager.default.fileExists(atPath: image.path))

    rig.actions.undoManager.undo()
    #expect(FileManager.default.fileExists(atPath: shot.file.path))
    #expect(FileManager.default.fileExists(atPath: image.path))
    try rig.fixture.reload()
    #expect(
      Self.names(rig) == [older, shot, newer].map { $0.file.lastPathComponent })
    #expect(model.selection == [shot.file.lastPathComponent])
    #expect(model.focus == .list)

    rig.actions.undoManager.redo()
    #expect(!FileManager.default.fileExists(atPath: shot.file.path))
    #expect(!FileManager.default.fileExists(atPath: image.path))
    try rig.fixture.reload()
    #expect(Self.names(rig) == [older, newer].map { $0.file.lastPathComponent })
    #expect(model.selection == [newer.file.lastPathComponent])

    rig.actions.undoManager.undo()
    try rig.fixture.reload()
    #expect(model.selection == [shot.file.lastPathComponent])
  }

  @Test func deletingSeveralThoughtsIsOneStepAndSaysSo() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    try rig.fixture.addText("a", daysAgo: 5)
    let second = try rig.fixture.addText("b", daysAgo: 4)
    let third = try rig.fixture.addText("c", daysAgo: 3)
    try rig.fixture.reload()
    model.selection = [second, third].map { $0.file.lastPathComponent }
    rig.actions.perform(.delete)
    await rig.actions.pending?.value
    #expect(
      model.feedback?.text == "Moved 2 thoughts to the Trash. Press ⌘Z to put them back.")
    rig.actions.undoManager.undo()
    try rig.fixture.reload()
    #expect(Self.names(rig).count == 3)
    #expect(model.selection == [second, third].map { $0.file.lastPathComponent })
    #expect(!rig.actions.undoManager.canUndo)
  }

  @Test func undoRightAfterDeleteBeatsTheListRefresh() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let only = try rig.fixture.addText("only", daysAgo: 1)
    try rig.fixture.reload()
    model.select(only.file.lastPathComponent, extend: false)
    rig.actions.perform(.delete)
    await rig.actions.pending?.value
    rig.actions.undoManager.undo()
    try rig.fixture.reload()
    #expect(Self.names(rig) == [only.file.lastPathComponent])
    #expect(model.selection == [only.file.lastPathComponent])
  }

  @Test func clearDoneThenUndoBringsBackExactlyTheClearedThoughts() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let first = try rig.fixture.addText("finished one", daysAgo: 4, done: true)
    let open = try rig.fixture.addText("open", daysAgo: 3)
    let second = try rig.fixture.addText("finished two", daysAgo: 2, done: true)
    try rig.fixture.reload()
    rig.actions.perform(.clearDone)
    await rig.actions.pending?.value
    #expect(model.feedback?.text == Self.clearNote)
    try rig.fixture.reload()
    #expect(Self.names(rig) == [open.file.lastPathComponent])

    rig.actions.undoManager.undo()
    try rig.fixture.reload()
    let all = try Self.stored(rig)
    #expect(all.allSatisfy { !$0.cleared })
    #expect(all.first { $0.id == first.id }?.done == ListFixture.now)
    #expect(Self.names(rig).count == 3)
    #expect(
      model.selection == [first, second].map { $0.file.lastPathComponent })

    rig.actions.undoManager.redo()
    try rig.fixture.reload()
    #expect(Self.names(rig) == [open.file.lastPathComponent])
    #expect(try Self.stored(rig).filter(\.cleared).count == 2)
  }

  @Test func doneThenUndoKeepsTheOriginalDateAndNotDoneComesBackWithIt() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let thought = try rig.fixture.addText("one", daysAgo: 3, done: true)
    try rig.fixture.reload()
    model.select(thought.file.lastPathComponent, extend: false)
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    #expect(try Self.stored(rig).first?.done == nil)

    rig.actions.undoManager.undo()
    #expect(try Self.stored(rig).first?.done == ListFixture.now)
    rig.actions.undoManager.redo()
    #expect(try Self.stored(rig).first?.done == nil)
    rig.actions.undoManager.undo()
    #expect(try Self.stored(rig).first?.done == ListFixture.now)
  }

  @Test func markingDoneThenUndoThenRedoUsesTheSameDate() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let thought = try rig.fixture.addText("one", daysAgo: 3)
    try rig.fixture.reload()
    model.select(thought.file.lastPathComponent, extend: false)
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    let date = ListFixture.now
    #expect(try Self.stored(rig).first?.done == date)
    rig.actions.undoManager.undo()
    #expect(try Self.stored(rig).first?.done == nil)
    rig.actions.undoManager.redo()
    #expect(try Self.stored(rig).first?.done == date)
  }

  @Test func aSavedEditThenUndoRestoresTheTextAndRedoPutsItBack() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let thought = try rig.fixture.addText("before", daysAgo: 1)
    try rig.fixture.reload()
    EditInPlaceTests.begin(rig, thought)
    model.editText = "after\n"
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    #expect(try Self.stored(rig).first?.content == .text("after"))

    rig.actions.undoManager.undo()
    #expect(try Self.stored(rig).first?.content == .text("before"))
    rig.actions.undoManager.redo()
    #expect(try Self.stored(rig).first?.content == .text("after"))
  }

  @Test func aSavedEditOnAScreenshotUndoesItsNote() async throws {
    let rig = try Self.rig()
    let shot = try rig.fixture.addScreenshot(note: "first note", daysAgo: 1)
    try rig.fixture.reload()
    EditInPlaceTests.begin(rig, shot)
    rig.fixture.model.editText = "second note"
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    rig.actions.undoManager.undo()
    guard case .image(_, let note) = try Self.stored(rig).first?.content else {
      Issue.record("expected a screenshot")
      return
    }
    #expect(note == "first note")
  }

  @Test func undoAfterTheFileChangedOnDiskSaysSoChangesNothingAndLeavesTheStack() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let thought = try rig.fixture.addText("one", daysAgo: 3)
    try rig.fixture.reload()
    model.select(thought.file.lastPathComponent, extend: false)
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    let edited = try #require(try Self.stored(rig).first)
    _ = try rig.fixture.store.setText("changed elsewhere", of: edited.id, expected: edited.version)

    rig.actions.undoManager.undo()
    #expect(model.feedback?.text == "Couldn't undo. The thought changed since then.")
    #expect(model.feedback?.kind == .message)
    let after = try #require(try Self.stored(rig).first)
    #expect(after.done != nil)
    #expect(after.content == .text("changed elsewhere"))
    #expect(!rig.actions.undoManager.canUndo)
    #expect(!rig.actions.undoManager.canRedo)
  }

  @Test func undoOfAFileThatWasDeletedElsewhereSaysTheThoughtChanged() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let thought = try rig.fixture.addText("one", daysAgo: 3)
    try rig.fixture.reload()
    model.select(thought.file.lastPathComponent, extend: false)
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    try FileManager.default.removeItem(at: thought.file)
    rig.actions.undoManager.undo()
    #expect(model.feedback?.text == "Couldn't undo. The thought changed since then.")
  }

  @Test func undoWithTheFileGoneFromTheTrashSaysSoAndTheNextUndoGoesBack() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let first = try rig.fixture.addText("one", daysAgo: 3)
    let second = try rig.fixture.addText("two", daysAgo: 2)
    try rig.fixture.reload()
    model.select(first.file.lastPathComponent, extend: false)
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    model.select(second.file.lastPathComponent, extend: false)
    rig.actions.perform(.delete)
    await rig.actions.pending?.value
    let trashed = try FileManager.default.contentsOfDirectory(
      at: rig.trashed.folder, includingPropertiesForKeys: nil)
    for slot in trashed { try FileManager.default.removeItem(at: slot) }

    rig.actions.undoManager.undo()
    #expect(model.feedback?.text == "Couldn't put it back. It's no longer in the Trash.")
    #expect(!FileManager.default.fileExists(atPath: second.file.path))
    #expect(rig.actions.undoManager.canUndo)
    rig.actions.undoManager.undo()
    #expect(try Self.stored(rig).first?.done == nil)
  }

  @Test func undoWithTheNameTakenSaysSoAndKeepsTheFileThatIsThere() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let only = try rig.fixture.addText("only", daysAgo: 1)
    try rig.fixture.reload()
    model.select(only.file.lastPathComponent, extend: false)
    rig.actions.perform(.delete)
    await rig.actions.pending?.value
    try Data("newer".utf8).write(to: only.file)

    rig.actions.undoManager.undo()
    #expect(
      model.feedback?.text
        == "Couldn't put it back. A file with that name is already in the folder.")
    #expect(try Data(contentsOf: only.file) == Data("newer".utf8))
    #expect(!rig.actions.undoManager.canUndo)
  }

  @Test func commandZWithNothingToUndoOrRedoSaysSoInsteadOfBeeping() throws {
    let rig = try Self.rig()
    let panel = ThoughtsPanel(content: NSView())
    panel.onNothingToDo = { [actions = rig.actions] in actions.nothingToDo($0) }
    let undo = try PanelKeyEquivalentTests.event("z", .command, code: 6, window: panel.windowNumber)
    #expect(panel.performKeyEquivalent(with: undo))
    #expect(rig.fixture.model.feedback?.text == "Nothing to undo")
    #expect(rig.fixture.model.feedback?.kind == .message)
    let redo = try PanelKeyEquivalentTests.event(
      "z", [.command, .shift], code: 6, window: panel.windowNumber)
    #expect(panel.performKeyEquivalent(with: redo))
    #expect(rig.fixture.model.feedback?.text == "Nothing to redo")
  }

  @Test func commandZAndShiftCommandZReachTheSharedStackWithTheListFocused() async throws {
    let fixture = try ListFixture()
    fixture.model.panelDidShow()
    let panel = ThoughtsPanel(content: NSView())
    let trash = FakeTrash(folder: fixture.root.appendingPathComponent("Trash"))
    let actions = ThoughtActions(
      list: fixture.model, location: fixture.location,
      pasteboard: PasteboardWriter(
        pasteboard: Throwaway.pasteboard()),
      trash: { try trash.move($0) }, undoManager: panel.sharedUndoManager)
    let only = try fixture.addText("only", daysAgo: 1)
    try fixture.reload()
    fixture.model.select(only.file.lastPathComponent, extend: false)
    actions.perform(.delete)
    await actions.pending?.value
    #expect(panel.undoManager === panel.sharedUndoManager)
    let undo = try PanelKeyEquivalentTests.event("z", .command, code: 6, window: panel.windowNumber)
    #expect(panel.performKeyEquivalent(with: undo))
    #expect(FileManager.default.fileExists(atPath: only.file.path))
    let redo = try PanelKeyEquivalentTests.event(
      "z", [.command, .shift], code: 6, window: panel.windowNumber)
    #expect(panel.performKeyEquivalent(with: redo))
    #expect(!FileManager.default.fileExists(atPath: only.file.path))
  }

  @Test func commandZRightAfterADeleteWaitsForItAndUndoesIt() async throws {
    let fixture = try ListFixture()
    fixture.model.panelDidShow()
    let panel = ThoughtsPanel(content: NSView())
    let trash = FakeTrash(folder: fixture.root.appendingPathComponent("Trash"))
    let actions = ThoughtActions(
      list: fixture.model, location: fixture.location,
      pasteboard: PasteboardWriter(
        pasteboard: Throwaway.pasteboard()),
      trash: { try trash.move($0) }, undoManager: panel.sharedUndoManager)
    panel.onNothingToDo = { actions.nothingToDo($0) }
    panel.defersHistory = { actions.deferIfBusy($0) }
    let only = try fixture.addText("only", daysAgo: 1)
    try fixture.reload()
    fixture.model.select(only.file.lastPathComponent, extend: false)
    actions.perform(.delete)
    let undo = try PanelKeyEquivalentTests.event("z", .command, code: 6, window: panel.windowNumber)
    #expect(panel.performKeyEquivalent(with: undo))
    await actions.pending?.value
    #expect(FileManager.default.fileExists(atPath: only.file.path))
    #expect(fixture.model.feedback?.text != "Nothing to undo")
    #expect(actions.busy == 0)
  }

  @Test func aDeleteThatFailsOnTheSecondOfThreeUndoesExactlyTheFirst() async throws {
    let fixture = try ListFixture()
    fixture.model.panelDidShow()
    let trash = FakeTrash(folder: fixture.root.appendingPathComponent("Trash"), failingOn: 2)
    let undoManager = UndoManager()
    undoManager.groupsByEvent = false
    let actions = ThoughtActions(
      list: fixture.model, location: fixture.location,
      pasteboard: PasteboardWriter(
        pasteboard: Throwaway.pasteboard()),
      trash: { try trash.move($0) }, undoManager: undoManager)
    let first = try fixture.addText("one", daysAgo: 3)
    let second = try fixture.addText("two", daysAgo: 2)
    let third = try fixture.addText("three", daysAgo: 1)
    try fixture.reload()
    fixture.model.selection = [first, second, third].map { $0.file.lastPathComponent }
    actions.perform(.delete)
    await actions.pending?.value
    #expect(fixture.model.feedback?.text == "The Trash is full")
    #expect(fixture.model.feedback?.kind == .message)
    #expect(!FileManager.default.fileExists(atPath: first.file.path))
    #expect(FileManager.default.fileExists(atPath: second.file.path))
    #expect(FileManager.default.fileExists(atPath: third.file.path))
    #expect(fixture.model.pendingRemoval == [first.file.lastPathComponent])

    undoManager.undo()
    #expect(FileManager.default.fileExists(atPath: first.file.path))
    #expect(FileManager.default.fileExists(atPath: second.file.path))
    #expect(FileManager.default.fileExists(atPath: third.file.path))
    #expect(!undoManager.canUndo)
  }

  @Test func clearDoneThatFailsOnTheSecondOfThreeUndoesExactlyTheFirst() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let first = try rig.fixture.addText("one", daysAgo: 4, done: true)
    let second = try rig.fixture.addText("two", daysAgo: 3, done: true)
    try rig.fixture.addText("three", daysAgo: 2, done: true)
    try rig.fixture.reload()
    try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: second.file.path)
    defer {
      try? FileManager.default.setAttributes(
        [.immutable: false], ofItemAtPath: second.file.path)
    }
    rig.actions.perform(.clearDone)
    await rig.actions.pending?.value
    #expect(model.feedback?.kind == .message)
    #expect(model.feedback?.text != Self.clearNote)
    #expect(try Self.stored(rig).filter(\.cleared).map(\.id) == [first.id])

    rig.actions.undoManager.undo()
    #expect(try Self.stored(rig).allSatisfy { !$0.cleared })
    #expect(try Self.stored(rig).first { $0.id == first.id }?.done == ListFixture.now)
    #expect(!rig.actions.undoManager.canUndo)
  }

  @Test func notesThatNameCommandZLastFourSecondsAndOtherConfirmationsKeepTheirs() async throws {
    #expect(Feedback.confirmationLifetime == .milliseconds(1500))
    #expect(Feedback.messageLifetime == .seconds(4))
    #expect(Feedback(kind: .confirmation, text: "Copied").lifetime == .milliseconds(1500))
    #expect(Feedback(kind: .confirmation, text: "x", lingers: true).lifetime == .seconds(4))
    #expect(Feedback(kind: .message, text: "x").lifetime == .seconds(4))

    let (rig, gate) = try ActionFeedbackTests.rig()
    let model = rig.fixture.model
    let finished = try rig.fixture.addText("one", daysAgo: 3, done: true)
    let open = try rig.fixture.addText("two", daysAgo: 2)
    try rig.fixture.reload()
    model.select(open.file.lastPathComponent, extend: false)
    rig.actions.perform(.copy)
    #expect(await Eventually.hold { await gate.requests().count == 1 })
    #expect(await gate.requests().last == .milliseconds(1500))
    rig.actions.perform(.delete)
    await rig.actions.pending?.value
    #expect(model.feedback?.text == Self.deleteNote)
    #expect(model.feedback?.kind == .confirmation)
    #expect(await Eventually.hold { await gate.requests().count == 2 })
    #expect(await gate.requests().last == .seconds(4))
    model.select(finished.file.lastPathComponent, extend: false)
    rig.actions.perform(.clearDone)
    await rig.actions.pending?.value
    #expect(model.feedback?.text == Self.clearNote)
    #expect(model.feedback?.kind == .confirmation)
    #expect(await Eventually.hold { await gate.requests().count == 3 })
    #expect(await gate.requests().last == .seconds(4))
  }

  @Test func twoSavedEditsOnOneThoughtUndoAndRedoInOrder() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let thought = try rig.fixture.addText("zero", daysAgo: 1)
    try rig.fixture.reload()
    EditInPlaceTests.begin(rig, thought)
    model.editText = "one"
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    model.perform(.edit)
    model.editText = "two"
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    #expect(try Self.stored(rig).first?.content == .text("two"))

    rig.actions.undoManager.undo()
    #expect(try Self.stored(rig).first?.content == .text("one"))
    rig.actions.undoManager.undo()
    #expect(try Self.stored(rig).first?.content == .text("zero"))
    rig.actions.undoManager.redo()
    rig.actions.undoManager.redo()
    #expect(try Self.stored(rig).first?.content == .text("two"))
    #expect(model.feedback?.kind != .message)
  }

  @Test func markDoneThenClearDoneUndoTwiceRestoresBoth() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let thought = try rig.fixture.addText("one", daysAgo: 1)
    try rig.fixture.reload()
    model.select(thought.file.lastPathComponent, extend: false)
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    rig.actions.perform(.clearDone)
    await rig.actions.pending?.value
    #expect(try Self.stored(rig).first?.cleared == true)

    rig.actions.undoManager.undo()
    #expect(try Self.stored(rig).first?.cleared == false)
    #expect(try Self.stored(rig).first?.done != nil)
    rig.actions.undoManager.undo()
    #expect(try Self.stored(rig).first?.done == nil)
    #expect(model.feedback?.kind != .message)
    rig.actions.undoManager.redo()
    rig.actions.undoManager.redo()
    #expect(try Self.stored(rig).first?.cleared == true)
  }

  @Test func editThenMarkDoneThenMarkNotDoneUndoThreeTimes() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let thought = try rig.fixture.addText("zero", daysAgo: 1)
    try rig.fixture.reload()
    EditInPlaceTests.begin(rig, thought)
    model.editText = "one"
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    for _ in 0..<3 { rig.actions.undoManager.undo() }
    let stored = try #require(try Self.stored(rig).first)
    #expect(stored.content == .text("zero") && stored.done == nil)
    #expect(model.feedback?.kind != .message)
  }

  @Test func anOutsideEditAfterTwoPanelChangesIsStillRefused() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let thought = try rig.fixture.addText("one", daysAgo: 1)
    try rig.fixture.reload()
    model.select(thought.file.lastPathComponent, extend: false)
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    rig.actions.perform(.toggleDone)
    await rig.actions.pending?.value
    let latest = try #require(try Self.stored(rig).first)
    _ = try rig.fixture.store.setText("outside", of: latest.id, expected: latest.version)
    rig.actions.undoManager.undo()
    #expect(model.feedback?.text == "Couldn't undo. The thought changed since then.")
    #expect(try Self.stored(rig).first?.content == .text("outside"))
    #expect(try Self.stored(rig).first?.done == nil)
  }

  @Test func commandZWhileANewDeleteIsRunningUndoesThatDeleteNotTheOlderStep() async throws {
    let fixture = try ListFixture()
    fixture.model.panelDidShow()
    let panel = ThoughtsPanel(content: NSView())
    panel.sharedUndoManager.groupsByEvent = false
    let release = DispatchSemaphore(value: 0)
    let hold = HoldFlag()
    let trash = FakeTrash(folder: fixture.root.appendingPathComponent("Trash"))
    let actions = ThoughtActions(
      list: fixture.model, location: fixture.location,
      pasteboard: PasteboardWriter(
        pasteboard: Throwaway.pasteboard()),
      trash: { url in
        if hold.value { release.wait() }
        return try trash.move(url)
      }, undoManager: panel.sharedUndoManager,
      now: { ListFixture.now })
    panel.onNothingToDo = { actions.nothingToDo($0) }
    panel.defersHistory = { actions.deferIfBusy($0) }
    let older = try fixture.addText("older", daysAgo: 3)
    let newer = try fixture.addText("newer", daysAgo: 1)
    try fixture.reload()
    fixture.model.select(older.file.lastPathComponent, extend: false)
    actions.perform(.toggleDone)
    await actions.pending?.value
    #expect(panel.sharedUndoManager.canUndo)

    hold.value = true
    fixture.model.select(newer.file.lastPathComponent, extend: false)
    actions.perform(.delete)
    let undo = try PanelKeyEquivalentTests.event("z", .command, code: 6, window: panel.windowNumber)
    #expect(panel.performKeyEquivalent(with: undo))
    #expect(
      try fixture.store.entries().compactMap(\.thought).first { $0.id == older.id }?.done != nil)
    release.signal()
    await actions.pending?.value
    #expect(FileManager.default.fileExists(atPath: newer.file.path))
    #expect(
      try fixture.store.entries().compactMap(\.thought).first { $0.id == older.id }?.done != nil)
  }

  @Test func restoredThoughtsAreRevealedAndNeverCountAsNewAdditions() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let old = try rig.fixture.addText("old", daysAgo: 5)
    try rig.fixture.addText("newer", daysAgo: 1)
    try rig.fixture.reload()
    model.select(old.file.lastPathComponent, extend: false)
    rig.actions.perform(.delete)
    await rig.actions.pending?.value
    try rig.fixture.reload()
    let before = model.addedCount
    rig.actions.undoManager.undo()
    _ = try rig.fixture.sync.rebuild()
    model.apply(IndexChanges(added: [old.file.lastPathComponent]))
    #expect(model.addedCount == before)
    #expect(model.selection == [old.file.lastPathComponent])

    let fresh = try rig.fixture.addText("fresh", daysAgo: 0)
    _ = try rig.fixture.sync.rebuild()
    model.apply(IndexChanges(added: [fresh.file.lastPathComponent]))
    #expect(model.addedCount == before + 1)
  }

  @Test func typingInAFieldJoinsTheSameStackAndUndoesFirstWhenItIsOnTop() async throws {
    let fixture = try ListFixture()
    fixture.model.panelDidShow()
    let edit = EditTextView()
    edit.frame = NSRect(x: 0, y: 0, width: 300, height: 40)
    let panel = ThoughtsPanel(content: edit)
    panel.sharedUndoManager.groupsByEvent = false
    let trash = FakeTrash(folder: fixture.root.appendingPathComponent("Trash"))
    let actions = ThoughtActions(
      list: fixture.model, location: fixture.location,
      pasteboard: PasteboardWriter(
        pasteboard: Throwaway.pasteboard()),
      trash: { try trash.move($0) }, undoManager: panel.sharedUndoManager)
    let only = try fixture.addText("only", daysAgo: 1)
    try fixture.reload()
    fixture.model.select(only.file.lastPathComponent, extend: false)
    actions.perform(.delete)
    await actions.pending?.value
    edit.setText("draft")
    #expect(panel.makeFirstResponder(edit))
    edit.setSelectedRange(NSRange(location: 5, length: 0))
    panel.sharedUndoManager.beginUndoGrouping()
    edit.insertText(" more", replacementRange: edit.selectedRange())
    panel.sharedUndoManager.endUndoGrouping()
    let undo = try PanelKeyEquivalentTests.event("z", .command, code: 6, window: panel.windowNumber)
    #expect(panel.performKeyEquivalent(with: undo))
    #expect(edit.string == "draft")
    #expect(!FileManager.default.fileExists(atPath: only.file.path))
    #expect(panel.performKeyEquivalent(with: undo))
    #expect(FileManager.default.fileExists(atPath: only.file.path))
    panel.makeFirstResponder(nil)
  }
}

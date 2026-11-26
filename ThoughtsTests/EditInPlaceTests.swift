import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct EditInPlaceTests {
  static func begin(_ rig: ThoughtActionsTests.Rig, _ thought: Thought) {
    rig.fixture.model.select(thought.file.lastPathComponent, extend: false)
    rig.fixture.model.perform(.edit)
  }

  @Test func enterSavesTheEditWithTheVersionReadWhenEditingBegan() async throws {
    let rig = try ThoughtActionsTests.rig()
    let thought = try rig.fixture.addText("Ask the team for the staging API key", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.onCommand = { rig.actions.perform($0) }
    Self.begin(rig, thought)
    #expect(rig.fixture.model.focus == .edit)
    #expect(rig.fixture.model.editText == "Ask the team for the staging API key")
    rig.fixture.model.editText = "Ask the team for the staging and prod keys\n"
    rig.fixture.model.perform(.saveEdit)
    await rig.actions.pending?.value
    let stored = try #require(try rig.fixture.store.entries().compactMap(\.thought).first)
    #expect(stored.content == .text("Ask the team for the staging and prod keys"))
    #expect(rig.fixture.model.editing == nil)
    #expect(rig.fixture.model.focus == .list)
    #expect(rig.fixture.model.selection == [thought.file.lastPathComponent])
    #expect(rig.fixture.model.entries.first?.thought?.content == stored.content)
  }

  @Test func aScreenshotEditsItsNote() async throws {
    let rig = try ThoughtActionsTests.rig()
    let shot = try rig.fixture.addScreenshot(note: "Rename fetchUser", daysAgo: 1)
    try rig.fixture.reload()
    Self.begin(rig, shot)
    #expect(rig.fixture.model.editText == "Rename fetchUser")
    rig.fixture.model.editText = ""
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    let stored = try #require(try rig.fixture.store.entries().compactMap(\.thought).first)
    guard case .image(let name, let note) = stored.content else {
      Issue.record("expected a screenshot")
      return
    }
    #expect(note.isEmpty)
    #expect(name == shot.imageFileURL?.lastPathComponent)
  }

  @Test func aChangeOnDiskKeepsTheTextAndTheNextEnterSaves() async throws {
    let rig = try ThoughtActionsTests.rig()
    let thought = try rig.fixture.addText("original", daysAgo: 1)
    try rig.fixture.reload()
    Self.begin(rig, thought)
    rig.fixture.model.editText = "my version"
    _ = try rig.fixture.store.setDone(true, for: thought.id, at: ListFixture.now)
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    #expect(rig.fixture.model.editing?.text == "my version")
    #expect(rig.fixture.model.editing?.isSaving == false)
    #expect(rig.fixture.model.focus == .edit)
    #expect(
      rig.fixture.model.feedback?.text == "Changed on disk. Press Enter again to save your text.")
    #expect(
      try rig.fixture.store.entries().compactMap(\.thought).first?.content == .text("original"))
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    let stored = try #require(try rig.fixture.store.entries().compactMap(\.thought).first)
    #expect(stored.content == .text("my version"))
    #expect(stored.done == ListFixture.now)
    #expect(rig.fixture.model.editing == nil)
  }

  @Test func aDeletedThoughtEndsTheEdit() async throws {
    let rig = try ThoughtActionsTests.rig()
    let thought = try rig.fixture.addText("original", daysAgo: 1)
    try rig.fixture.reload()
    Self.begin(rig, thought)
    rig.fixture.model.editText = "changed my mind"
    try FileManager.default.removeItem(at: thought.file)
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    #expect(rig.fixture.model.editing == nil)
    #expect(rig.fixture.model.focus == .list)
    #expect(rig.fixture.model.feedback?.text == "This thought was deleted.")
  }

  @Test func escapeCancelsWithoutWritingAndAnUnchangedTextWritesNothing() async throws {
    let rig = try ThoughtActionsTests.rig()
    let thought = try rig.fixture.addText("original", daysAgo: 1)
    try rig.fixture.reload()
    let before = try #require(try rig.fixture.store.entries().compactMap(\.thought).first).version
    Self.begin(rig, thought)
    rig.fixture.model.editText = "typed then dropped"
    rig.fixture.model.perform(.cancelEdit)
    #expect(rig.fixture.model.editing == nil)
    #expect(rig.fixture.model.focus == .list)
    Self.begin(rig, thought)
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    #expect(rig.fixture.model.editing == nil)
    let after = try #require(try rig.fixture.store.entries().compactMap(\.thought).first).version
    #expect(after == before)
  }

  @Test func aBlankTextThoughtStaysInEditing() async throws {
    let rig = try ThoughtActionsTests.rig()
    let thought = try rig.fixture.addText("original", daysAgo: 1)
    try rig.fixture.reload()
    Self.begin(rig, thought)
    rig.fixture.model.editText = " \n "
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    #expect(rig.fixture.model.editing != nil)
    #expect(
      try rig.fixture.store.entries().compactMap(\.thought).first?.content == .text("original"))
  }

  @Test func clickingInsideTheEditedRowKeepsTheText() throws {
    let rig = try ThoughtActionsTests.rig()
    let first = try rig.fixture.addText("one", daysAgo: 2)
    try rig.fixture.reload()
    Self.begin(rig, first)
    rig.fixture.model.editText = "kept while clicking inside"
    rig.fixture.model.select(first.file.lastPathComponent, extend: false)
    #expect(rig.fixture.model.editText == "kept while clicking inside")
    #expect(rig.fixture.model.focus == .edit)
  }

  @Test func clickingAnotherRowSavesTheEditThenMovesTheSelection() async throws {
    let rig = try ThoughtActionsTests.rig()
    let first = try rig.fixture.addText("one", daysAgo: 2)
    let second = try rig.fixture.addText("two", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.onCommand = { rig.actions.perform($0) }
    Self.begin(rig, first)
    rig.fixture.model.editText = "one, edited"
    rig.fixture.model.select(second.file.lastPathComponent, extend: false)
    #expect(rig.fixture.model.selection == [first.file.lastPathComponent])
    await rig.actions.pending?.value
    #expect(rig.fixture.model.editing == nil)
    #expect(rig.fixture.model.selection == [second.file.lastPathComponent])
    #expect(rig.fixture.model.focus == .list)
    let stored = try rig.fixture.store.entries().compactMap(\.thought)
    #expect(stored.contains { $0.content == .text("one, edited") })
  }

  @Test func clickingAnotherRowWithTheTextUnchangedMovesAtOnce() throws {
    let rig = try ThoughtActionsTests.rig()
    let first = try rig.fixture.addText("one", daysAgo: 2)
    let second = try rig.fixture.addText("two", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.onCommand = { rig.actions.perform($0) }
    Self.begin(rig, first)
    rig.fixture.model.select(second.file.lastPathComponent, extend: false)
    #expect(rig.fixture.model.editing == nil)
    #expect(rig.fixture.model.selection == [second.file.lastPathComponent])
  }

  @Test func aConflictOnClickAwayKeepsTheEditAndTheSelection() async throws {
    let rig = try ThoughtActionsTests.rig()
    let first = try rig.fixture.addText("one", daysAgo: 2)
    let second = try rig.fixture.addText("two", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.onCommand = { rig.actions.perform($0) }
    Self.begin(rig, first)
    rig.fixture.model.editText = "my version"
    _ = try rig.fixture.store.setDone(true, for: first.id, at: ListFixture.now)
    rig.fixture.model.select(second.file.lastPathComponent, extend: false)
    await rig.actions.pending?.value
    #expect(rig.fixture.model.editing?.name == first.file.lastPathComponent)
    #expect(rig.fixture.model.editing?.text == "my version")
    #expect(rig.fixture.model.selection == [first.file.lastPathComponent])
    #expect(
      rig.fixture.model.feedback?.text == "Changed on disk. Press Enter again to save your text.")
  }

  @Test func hidingThePanelKeepsTheEditAndItsText() throws {
    let rig = try ThoughtActionsTests.rig()
    let first = try rig.fixture.addText("one", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.panelDidShow()
    Self.begin(rig, first)
    rig.fixture.model.editText = "half typed"
    rig.fixture.model.panelDidHide()
    rig.fixture.model.panelDidShow()
    #expect(rig.fixture.model.editing?.text == "half typed")
    #expect(rig.fixture.model.editing?.name == first.file.lastPathComponent)
    rig.fixture.model.perform(.cancelEdit)
    #expect(rig.fixture.model.editing == nil)
  }

  @Test func aSaveResultForAnotherRowDoesNotEndTheCurrentEdit() throws {
    let rig = try ThoughtActionsTests.rig()
    let first = try rig.fixture.addText("one", daysAgo: 2)
    let second = try rig.fixture.addText("two", daysAgo: 1)
    try rig.fixture.reload()
    Self.begin(rig, first)
    rig.fixture.model.perform(.cancelEdit)
    Self.begin(rig, second)
    rig.fixture.model.editText = "second, typing"
    let saved = try rig.fixture.store.setText("one, saved", of: first.id, expected: first.version)
    rig.fixture.model.finishEdit(.saved(saved), for: first.file.lastPathComponent)
    rig.fixture.model.finishEdit(.deleted, for: first.file.lastPathComponent)
    rig.fixture.model.finishEdit(.failed("nope"), for: first.file.lastPathComponent)
    #expect(rig.fixture.model.editing?.name == second.file.lastPathComponent)
    #expect(rig.fixture.model.editing?.text == "second, typing")
    #expect(rig.fixture.model.focus == .edit)
  }

  @Test func leavingTheEditForTheInputSavesItBeforeAnotherRowCanBeEdited() async throws {
    let rig = try ThoughtActionsTests.rig()
    let first = try rig.fixture.addText("one", daysAgo: 2)
    let second = try rig.fixture.addText("two", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.onCommand = { rig.actions.perform($0) }
    Self.begin(rig, first)
    rig.fixture.model.editText = "one, edited"
    rig.fixture.model.focus = .input
    #expect(rig.fixture.model.editing?.isSaving == true)
    rig.fixture.model.perform(.selectNewest)
    rig.fixture.model.perform(.edit)
    #expect(rig.fixture.model.editing?.name == first.file.lastPathComponent)
    await rig.actions.pending?.value
    let stored = try rig.fixture.store.entries().compactMap(\.thought)
    #expect(stored.contains { $0.content == .text("one, edited") })
    #expect(rig.fixture.model.editing == nil)
    #expect(rig.fixture.model.focus == .list)
    rig.fixture.model.perform(.edit)
    #expect(rig.fixture.model.editing?.name == second.file.lastPathComponent)
  }

  @Test func leavingTheEditForSearchOrTheMenuSavesIt() async throws {
    let rig = try ThoughtActionsTests.rig()
    let first = try rig.fixture.addText("one", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.onCommand = { rig.actions.perform($0) }
    Self.begin(rig, first)
    rig.fixture.model.editText = "one, edited"
    rig.fixture.model.focus = .search
    await rig.actions.pending?.value
    #expect(rig.fixture.model.editing == nil)
    #expect(rig.fixture.model.focus == .search)
    let stored = try rig.fixture.store.entries().compactMap(\.thought)
    #expect(stored.first?.content == .text("one, edited"))
  }

  @Test func aConflictOnLeavingTheEditReturnsFocusToItsField() async throws {
    let rig = try ThoughtActionsTests.rig()
    let first = try rig.fixture.addText("one", daysAgo: 2)
    try rig.fixture.addText("two", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.onCommand = { rig.actions.perform($0) }
    Self.begin(rig, first)
    rig.fixture.model.editText = "my version"
    _ = try rig.fixture.store.setDone(true, for: first.id, at: ListFixture.now)
    rig.fixture.model.focus = .input
    await rig.actions.pending?.value
    #expect(rig.fixture.model.editing?.name == first.file.lastPathComponent)
    #expect(rig.fixture.model.editing?.text == "my version")
    #expect(rig.fixture.model.focus == .edit)
    #expect(rig.fixture.model.selection == [first.file.lastPathComponent])
    #expect(
      rig.fixture.model.feedback?.text == "Changed on disk. Press Enter again to save your text.")
  }

  @Test func aBlankTextCannotBeLeftBehind() throws {
    let rig = try ThoughtActionsTests.rig()
    let first = try rig.fixture.addText("one", daysAgo: 1)
    try rig.fixture.reload()
    rig.fixture.model.onCommand = { rig.actions.perform($0) }
    Self.begin(rig, first)
    rig.fixture.model.editText = "  "
    rig.fixture.model.focus = .input
    #expect(rig.fixture.model.focus == .edit)
    #expect(rig.fixture.model.editing?.text == "  ")
  }
}

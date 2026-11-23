import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct EditInPlaceTests {
  static func begin(_ rig: ThoughtActionsTests.Rig, _ thought: Thought) {
    rig.fixture.model.select(thought.file.lastPathComponent, extend: false)
    rig.fixture.model.perform(.edit)
  }

  @Test func enterSavesTheEditWithTheVersionReadWhenEditingBegan() async throws {
    let rig = try ThoughtActionsTests.rig()
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
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
      rig.fixture.model.hint == "Changed on disk. Press Enter again to save your text.")
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
    defer { rig.board.releaseGlobally() }
    let thought = try rig.fixture.addText("original", daysAgo: 1)
    try rig.fixture.reload()
    Self.begin(rig, thought)
    rig.fixture.model.editText = "changed my mind"
    try FileManager.default.removeItem(at: thought.file)
    rig.actions.perform(.saveEdit)
    await rig.actions.pending?.value
    #expect(rig.fixture.model.editing == nil)
    #expect(rig.fixture.model.focus == .list)
    #expect(rig.fixture.model.hint == "This thought was deleted.")
  }

  @Test func escapeCancelsWithoutWritingAndAnUnchangedTextWritesNothing() async throws {
    let rig = try ThoughtActionsTests.rig()
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
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

  @Test func clickingAnotherRowEndsTheEditAndClickingTheEditedRowKeepsIt() throws {
    let rig = try ThoughtActionsTests.rig()
    defer { rig.board.releaseGlobally() }
    let first = try rig.fixture.addText("one", daysAgo: 2)
    let second = try rig.fixture.addText("two", daysAgo: 1)
    try rig.fixture.reload()
    Self.begin(rig, first)
    rig.fixture.model.editText = "kept while clicking inside"
    rig.fixture.model.select(first.file.lastPathComponent, extend: false)
    #expect(rig.fixture.model.editText == "kept while clicking inside")
    rig.fixture.model.select(second.file.lastPathComponent, extend: false)
    #expect(rig.fixture.model.editing == nil)
  }
}

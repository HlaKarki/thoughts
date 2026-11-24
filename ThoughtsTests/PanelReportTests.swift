import AppKit
import Testing

@testable import Thoughts

@MainActor
@Suite(.serialized)
struct PanelReportTests {
  @Test func arrowKeysInTheActionsMenuMoveItsHighlightAndKeepTheSelection() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      await harness.press(.up)
      let selected = harness.list.selection
      #expect(selected.count == 1)
      await harness.press(.character("k"), .command)
      #expect(harness.list.isMenuOpen)
      withKnownIssue("Opening the menu hands focus to the search field") {
        #expect(harness.list.focus == .menu)
      }
      await harness.press(.down)
      withKnownIssue("Down moves the list instead of the menu highlight") {
        #expect(harness.list.isMenuOpen)
        #expect(harness.list.menuHighlight == 1)
        #expect(harness.list.selection == selected)
      }
      await harness.press(.up)
      withKnownIssue("Up moves the list selection") {
        #expect(harness.list.isMenuOpen)
        #expect(harness.list.menuHighlight == 0)
        #expect(harness.list.selection == selected)
      }
    }
  }

  @Test func shiftReturnInTheInputAddsALineAndAddsNothing() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      await harness.type("one")
      await harness.press(.returnKey, .shift)
      await harness.type("two")
      withKnownIssue("Shift Return ends editing and selects the typed text") {
        #expect(harness.input.text == "one\ntwo")
      }
      await harness.submitted()
      #expect(try harness.storedTexts.isEmpty)
    }
  }

  @Test func commandZUndoesTypingInTheInput() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      await harness.type("hello")
      await harness.press(.character("z"), .command)
      withKnownIssue("The undo clears the field editor but the model keeps the text") {
        #expect(harness.input.text == "")
      }
      await harness.press(.returnKey)
      await harness.submitted()
      let stored = try harness.storedTexts
      withKnownIssue("Return after the undo still saves the undone text") {
        #expect(stored.isEmpty)
      }
    }
  }

  @Test func commandZUndoesTypingInSearch() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["alpha", "beta"])
      try await harness.show()
      await harness.press(.character("f"), .command)
      #expect(harness.list.focus == .search)
      await harness.type("al")
      #expect(harness.list.query == "al")
      await harness.press(.character("z"), .command)
      withKnownIssue("The panel checks only its own undo manager and says Nothing to undo") {
        #expect(harness.list.query == "")
        #expect(harness.list.feedback?.text != "Nothing to undo")
      }
    }
  }

  @Test func commandZUndoesTypingInAnOpenEdit() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["first"])
      try await harness.show()
      await harness.press(.up)
      await harness.press(.returnKey)
      #expect(harness.list.focus == .edit)
      await harness.type("x")
      #expect(harness.list.editText == "firstx")
      await harness.press(.character("z"), .command)
      #expect(harness.list.editText == "first")
    }
  }

  @Test func commandZOnTheListBringsBackADeletedThought() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two"])
      try await harness.show()
      await harness.press(.up)
      await harness.press(.delete, .command)
      await harness.actions.pending?.value
      #expect(try harness.storedTexts.sorted() == ["one"])
      await harness.press(.character("z"), .command)
      await harness.actions.pending?.value
      #expect(try harness.storedTexts.sorted() == ["one", "two"])
    }
  }
}

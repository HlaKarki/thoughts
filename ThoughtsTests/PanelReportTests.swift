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
      await harness.press(.up)
      let middle = try #require(harness.list.visible.dropFirst().first?.fileName)
      #expect(harness.list.selection == [middle])
      await harness.press(.character("k"), .command)
      #expect(harness.list.isMenuOpen)
      #expect(harness.list.focus == .menu)
      #expect(harness.isEditing(harness.field(MenuTextField.self)))
      await harness.press(.down)
      #expect(harness.list.isMenuOpen)
      #expect(harness.list.menuHighlight == 1)
      #expect(harness.list.selection == [middle])
      await harness.press(.up)
      #expect(harness.list.isMenuOpen)
      #expect(harness.list.menuHighlight == 0)
      #expect(harness.list.selection == [middle])
    }
  }

  enum Row: String, Sendable {
    case newest
    case oldest
  }

  @Test(arguments: [
    (Row.newest, Focus.menu), (.newest, .list), (.newest, .search), (.oldest, .menu),
  ])
  func upFiveTimesInTheMenuKeepsItOpenAndTheSelection(_ row: Row, _ held: Focus) async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      await harness.press(.up)
      if row == .oldest {
        await harness.press(.up)
        await harness.press(.up)
      }
      let names = harness.list.visible.map(\.fileName)
      let selected = try #require(row == .newest ? names.last : names.first)
      #expect(harness.list.selection == [selected])
      await harness.press(.character("k"), .command)
      #expect(harness.list.focus == .menu)
      harness.list.focus = held
      await harness.settle("after \(held) took focus")
      #expect(harness.list.menuHighlight == 0)
      for _ in 0..<5 { await harness.press(.up) }
      #expect(harness.list.isMenuOpen)
      #expect(harness.list.menuHighlight == 0)
      #expect(harness.list.selection == [selected])
    }
  }

  @Test func theOpenMenuTakesItsKeysWhileTheSearchFieldHoldsFocus() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      await harness.press(.up)
      let selected = harness.list.selection
      await harness.press(.character("k"), .command)
      harness.list.focus = .search
      await harness.settle("after search took focus")
      #expect(harness.isEditing(harness.field(SearchTextField.self)))
      await harness.press(.down)
      #expect(harness.list.menuHighlight == 1)
      await harness.press(.up)
      #expect(harness.list.menuHighlight == 0)
      #expect(harness.list.isMenuOpen)
      #expect(harness.list.selection == selected)
      await harness.press(.character("k"), .command)
      #expect(!harness.list.isMenuOpen)
      #expect(harness.list.selection == selected)
      #expect(harness.list.query == "")
    }
  }

  @Test func aFieldTakingFocusWhileTheMenuIsOpenLeavesTheMenuFocused() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two"])
      try await harness.show()
      await harness.press(.up)
      await harness.press(.character("k"), .command)
      let search = try #require(harness.field(SearchTextField.self))
      #expect(harness.panel.makeFirstResponder(search))
      #expect(harness.list.focus == .menu)
      await harness.press(.escape)
      #expect(!harness.list.isMenuOpen)
      #expect(harness.list.focus == .list)
      #expect(harness.hideRequests == 0)
    }
  }

  @Test func typingWithTheMenuOpenFiltersItsSearchField() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two"])
      try await harness.show()
      await harness.press(.up)
      await harness.press(.character("k"), .command)
      await harness.type("edit")
      #expect(harness.list.menuQuery == "edit")
      #expect(harness.list.query == "")
      #expect(harness.firstResponderText == "edit")
      #expect(harness.list.menuItems.map(\.command) == [.edit])
      await harness.press(.returnKey)
      #expect(!harness.list.isMenuOpen)
      #expect(harness.list.focus == .edit)
      #expect(harness.list.editText == "two")
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

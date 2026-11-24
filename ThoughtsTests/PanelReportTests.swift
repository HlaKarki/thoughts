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

  @Test func aFieldTakingFocusWhileTheMenuIsOpenGivesItBackToTheMenuField() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two"])
      try await harness.show()
      await harness.press(.up)
      let selected = harness.list.selection
      await harness.press(.character("k"), .command)
      let search = try #require(harness.field(SearchTextField.self))
      #expect(harness.panel.makeFirstResponder(search))
      await harness.settle("after the search field took focus")
      #expect(harness.list.focus == .menu)
      #expect(!harness.isEditing(search))
      #expect(harness.isEditing(harness.field(MenuTextField.self)))
      await harness.type("edit")
      #expect(harness.list.menuQuery == "edit")
      #expect(harness.list.query == "")
      #expect(harness.list.selection == selected)
      await harness.press(.escape)
      #expect(!harness.list.isMenuOpen)
      #expect(harness.list.focus == .list)
      #expect(harness.hideRequests == 0)
    }
  }

  @Test func tabAndShiftTabWithTheMenuOpenKeepTheMenuFieldTyping() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two"])
      try await harness.show()
      await harness.press(.up)
      let selected = harness.list.selection
      await harness.press(.character("k"), .command)
      await harness.press(.tab)
      await harness.press(.tab, .shift)
      await harness.type("edit")
      #expect(harness.list.isMenuOpen)
      #expect(harness.list.focus == .menu)
      #expect(harness.list.menuQuery == "edit")
      #expect(harness.list.query == "")
      #expect(harness.list.selection == selected)
      #expect(harness.isEditing(harness.field(MenuTextField.self)))
      #expect(!harness.isEditing(harness.field(SearchTextField.self)))
      #expect(!harness.isEditing(harness.inputField))
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
      #expect(harness.panel.firstResponder is PasteFieldEditor)
      await harness.press(.returnKey, .shift)
      #expect(harness.list.isMenuOpen)
      #expect(harness.list.menuQuery == "edit")
      #expect((harness.panel.firstResponder as? NSTextView)?.selectedRange().length == 0)
      await harness.press(.character("z"), .command)
      #expect(harness.list.menuQuery == "")
      #expect(harness.list.isMenuOpen)
      await harness.press(.character("z"), [.command, .shift])
      #expect(harness.list.menuQuery == "edit")
      await harness.press(.returnKey)
      #expect(!harness.list.isMenuOpen)
      #expect(harness.list.focus == .edit)
      #expect(harness.list.editText == "two")
    }
  }

  @Test func shiftReturnInTheInputAddsALineAtTheCaretAndAddsNothing() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      await harness.type("onetwo")
      let editor = try #require(harness.panel.firstResponder as? NSTextView)
      editor.setSelectedRange(NSRange(location: 3, length: 0))
      await harness.press(.returnKey, .shift)
      #expect(harness.input.text == "one\ntwo")
      #expect(harness.firstResponderText == "one\ntwo")
      #expect(editor.selectedRange() == NSRange(location: 4, length: 0))
      #expect(harness.isEditing(harness.inputField))
      await harness.submitted()
      #expect(try harness.storedTexts.isEmpty)
    }
  }

  @Test func returnAddsTheThoughtWithItsLineBreaks() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      await harness.type("one")
      await harness.press(.returnKey, .shift)
      await harness.type("two")
      await harness.press(.returnKey)
      await harness.submitted()
      #expect(try harness.storedTexts == ["one\ntwo"])
      #expect(harness.input.text == "")
      #expect(harness.firstResponderText == "")
    }
  }

  @Test func theInputGrowsALineAtATimeUpToFiveAndTheListGivesUpTheSpace() async throws {
    try await PanelHarness.run { harness in
      try harness.seed((1...15).map { "thought \($0)" })
      try await harness.show()
      let field = try #require(harness.inputField)
      let list = try #require(harness.listScroller)
      let panel = harness.panel.frame
      let fieldStart = field.convert(field.bounds, to: nil)
      let listStart = list.convert(list.bounds, to: nil)
      let line = InputField.lineHeight
      #expect(harness.isScrolledToBottom(list))
      await harness.type("a")
      for lines in 2...7 {
        await harness.press(.returnKey, .shift)
        await harness.type("a")
        let shown = CGFloat(min(lines, InputField.maxLines))
        let fieldNow = field.convert(field.bounds, to: nil)
        let listNow = list.convert(list.bounds, to: nil)
        #expect(harness.panel.frame == panel)
        #expect(fieldNow.minY == fieldStart.minY, "the input moved at \(lines) lines")
        #expect(fieldNow.height == fieldStart.height + (shown - 1) * line, "at \(lines) lines")
        #expect(listNow.maxY == listStart.maxY, "the list top moved at \(lines) lines")
        #expect(listNow.minY == listStart.minY + (shown - 1) * line, "at \(lines) lines")
        #expect(harness.isScrolledToBottom(list), "the list left its bottom at \(lines) lines")
        #expect(harness.caretIsVisible(), "the caret is out of view at \(lines) lines")
      }
      #expect(harness.input.text == Array(repeating: "a", count: 7).joined(separator: "\n"))
      await harness.press(.returnKey)
      await harness.submitted()
      await harness.settle("after the add")
      #expect(field.convert(field.bounds, to: nil) == fieldStart)
      #expect(list.convert(list.bounds, to: nil) == listStart)
    }
  }

  @Test func theFirstSummonOfAPanelNeverLaidOutFocusesTheInput() async throws {
    try await PanelHarness.run(laidOut: false) { harness in
      try harness.seed(["one", "two"])
      try await harness.show()
      #expect(harness.list.focus == .input)
      #expect(harness.isEditing(harness.inputField))
      await harness.type("hi")
      #expect(harness.input.text == "hi")
      #expect(harness.list.query == "")
    }
  }

  @Test(arguments: [Focus.input, .list])
  func aFieldTakingFocusOnItsOwnGivesItBackToTheModelsChoice(_ held: Focus) async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two"])
      try await harness.show()
      if held == .list { await harness.press(.up) }
      let search = try #require(harness.field(SearchTextField.self))
      #expect(harness.panel.makeFirstResponder(search))
      await harness.settle("after the search field took focus")
      #expect(harness.list.focus == held)
      #expect(!harness.isEditing(search))
      #expect(harness.isEditing(harness.inputField) == (held == .input))
      await harness.type("x")
      #expect(harness.list.focus == .input)
      #expect(harness.list.query == "")
      #expect(harness.input.text == "x")
    }
  }

  @Test func theActionsMenuStaysAboveAGrownInput() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two"])
      try await harness.show()
      let field = try #require(harness.inputField)
      await harness.press(.up)
      await harness.press(.character("k"), .command)
      let menu = try #require(harness.field(MenuTextField.self))
      let gap = menu.convert(menu.bounds, to: nil).minY - field.convert(field.bounds, to: nil).maxY
      await harness.press(.escape)
      await harness.press(.escape)
      #expect(harness.list.focus == .input)
      await harness.type("a")
      await harness.press(.returnKey, .shift)
      await harness.type("b")
      await harness.press(.returnKey, .shift)
      await harness.type("c")
      await harness.press(.character("f"), .command)
      await harness.press(.down)
      await harness.press(.character("k"), .command)
      #expect(harness.list.isMenuOpen)
      #expect(harness.input.text == "a\nb\nc")
      let grown = try #require(harness.field(MenuTextField.self))
      let fieldTop = field.convert(field.bounds, to: nil).maxY
      #expect(grown.convert(grown.bounds, to: nil).minY - fieldTop == gap)
    }
  }

  @Test(arguments: [NSEvent.ModifierFlags(), .shift])
  func returnInSearchMovesToTheFirstResultLikeDown(_ flags: NSEvent.ModifierFlags) async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["apple", "apricot", "beta"])
      try await harness.show()
      await harness.press(.character("f"), .command)
      await harness.type("zz")
      #expect(harness.list.visible.isEmpty)
      await harness.press(.returnKey, flags)
      #expect(harness.list.focus == .search)
      #expect(harness.list.query == "zz")
      #expect(harness.isEditing(harness.field(SearchTextField.self)))
      let editor = try #require(harness.panel.firstResponder as? NSTextView)
      #expect(editor.string == "zz")
      #expect(editor.selectedRange() == NSRange(location: 2, length: 0))
      editor.setSelectedRange(NSRange(location: 0, length: 2))
      await harness.press(.delete)
      await harness.type("ap")
      #expect(harness.list.visible.count == 2)
      await harness.press(.returnKey, flags)
      #expect(harness.list.focus == .list)
      #expect(harness.list.selection == [try #require(harness.list.visible.first?.fileName)])
      #expect(harness.list.query == "ap")
    }
  }

  @Test func shiftReturnAndReturnInAnOpenEditAddALineThenSave() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["first"])
      try await harness.show()
      await harness.press(.up)
      await harness.press(.returnKey)
      #expect(harness.list.focus == .edit)
      await harness.press(.returnKey, .shift)
      await harness.type("two")
      #expect(harness.list.editText == "first\ntwo")
      await harness.press(.returnKey)
      await harness.actions.pending?.value
      #expect(harness.list.editing == nil)
      #expect(try harness.storedTexts == ["first\ntwo"])
    }
  }

  @Test func commandZUndoesTypingInTheInput() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      await harness.type("hello")
      await harness.press(.character("z"), .command)
      #expect(harness.input.text == "")
      #expect(harness.firstResponderText == "")
      #expect(harness.list.feedback?.text != "Nothing to undo")
      await harness.press(.returnKey)
      await harness.submitted()
      #expect(try harness.storedTexts.isEmpty)
    }
  }

  @Test func commandShiftZRedoesTypingInTheInput() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      await harness.type("hello")
      await harness.press(.character("z"), .command)
      await harness.press(.character("z"), [.command, .shift])
      #expect(harness.input.text == "hello")
      #expect(harness.firstResponderText == "hello")
      await harness.press(.returnKey)
      await harness.submitted()
      #expect(try harness.storedTexts == ["hello"])
    }
  }

  @Test func commandZAfterAnAddLeavesTheInputEmptyAndTheThoughtSaved() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      await harness.type("hello")
      harness.endEventUndoGroup()
      await harness.press(.returnKey)
      await harness.submitted()
      await harness.settle("after the add")
      await harness.press(.character("z"), .command)
      #expect(harness.input.text == "")
      #expect(harness.firstResponderText == "")
      #expect(harness.list.feedback?.text == "Nothing to undo")
      #expect(try harness.storedTexts == ["hello"])
      await harness.type("abc")
      await harness.press(.character("z"), .command)
      #expect(harness.input.text == "")
      #expect(try harness.storedTexts == ["hello"])
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
      #expect(harness.list.visible.count == 1)
      await harness.press(.character("z"), .command)
      #expect(harness.list.query == "")
      #expect(harness.firstResponderText == "")
      #expect(harness.list.feedback?.text != "Nothing to undo")
      #expect(harness.list.visible.count == 2)
      await harness.press(.character("z"), [.command, .shift])
      #expect(harness.list.query == "al")
      #expect(harness.list.visible.count == 1)
    }
  }

  @Test func undoInOneFieldNeverReachesTheTextOfAnother() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["alpha", "beta"])
      try await harness.show()
      await harness.type("hello")
      await harness.press(.character("f"), .command)
      #expect(harness.input.text == "hello")
      await harness.type("al")
      #expect(harness.list.query == "al")
      #expect(harness.input.text == "hello")
      await harness.press(.character("z"), .command)
      #expect(harness.list.query == "")
      await harness.press(.character("z"), .command)
      #expect(harness.list.feedback?.text == "Nothing to undo")
      #expect(harness.list.query == "")
      #expect(harness.firstResponderText == "")
      #expect(harness.input.text == "hello")
      #expect(harness.inputField?.stringValue == "hello")
      await harness.press(.character("z"), [.command, .shift])
      #expect(harness.list.query == "al")
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

  @Test(arguments: [false, true])
  func commandZAfterTypingInTheMenuAndClosingItBringsBackADeletedThought(_ eventGroups: Bool)
    async throws
  {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      await harness.press(.up)
      await harness.press(.delete, .command)
      await harness.actions.pending?.value
      #expect(try harness.storedTexts.sorted() == ["one", "two"])
      #expect(!harness.list.selection.isEmpty)
      if eventGroups { harness.endEventUndoGroup() }
      await harness.press(.character("k"), .command)
      #expect(harness.list.isMenuOpen)
      await harness.type("x")
      #expect(harness.list.menuQuery == "x")
      if eventGroups { harness.endEventUndoGroup() }
      await harness.press(.escape)
      #expect(!harness.list.isMenuOpen)
      await harness.press(.character("z"), .command)
      await harness.actions.pending?.value
      let texts = try harness.storedTexts.sorted()
      #expect(texts == ["one", "three", "two"])
    }
  }
}

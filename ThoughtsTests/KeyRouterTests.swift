import AppKit
import SwiftUI
import Testing

@testable import Thoughts

struct KeyRouterCase: Sendable, CustomTestStringConvertible {
  let name: String
  let key: KeyEquivalent
  var modifiers: EventModifiers = []
  var focus: Focus = .input
  var menuIsOpen = false
  var inputIsEmpty = true
  var hasAttachment = false
  var characters = ""
  let expected: KeyCommand?

  var testDescription: String { name }
}

enum KeyRouterCases {
  static let all: [KeyRouterCase] = input + search + list + menu + edit + openMenu

  static let input: [KeyRouterCase] = [
    KeyRouterCase(name: "Return in the input adds", key: .return, expected: .add),
    KeyRouterCase(
      name: "Shift Return in the input is left to the field", key: .return, modifiers: .shift,
      expected: nil),
    KeyRouterCase(
      name: "Up in an empty input selects the newest", key: .upArrow, expected: .selectNewest),
    KeyRouterCase(
      name: "Up in a typed input stays in the field", key: .upArrow, inputIsEmpty: false,
      expected: nil),
    KeyRouterCase(
      name: "Command F in the input jumps to search", key: KeyEquivalent("f"),
      modifiers: .command, expected: .focusSearch),
    KeyRouterCase(name: "Esc in the input hides the panel", key: .escape, expected: .hidePanel),
    KeyRouterCase(
      name: "Esc with an attachment removes it", key: .escape, hasAttachment: true,
      expected: .removeAttachment),
    KeyRouterCase(
      name: "Command V is left to the field", key: KeyEquivalent("v"), modifiers: .command,
      expected: nil),
    KeyRouterCase(
      name: "Command C is left to the field", key: KeyEquivalent("c"), modifiers: .command,
      expected: nil),
    KeyRouterCase(
      name: "Command K needs a selection", key: KeyEquivalent("k"), modifiers: .command,
      expected: nil),
    KeyRouterCase(
      name: "Typing a letter is left to the field", key: KeyEquivalent("a"), characters: "a",
      expected: nil),
  ]

  static let search: [KeyRouterCase] = [
    KeyRouterCase(
      name: "Esc in search clears it", key: .escape, focus: .search, expected: .clearSearch),
    KeyRouterCase(
      name: "Down in search moves into the results", key: .downArrow, focus: .search,
      expected: .move(1)),
    KeyRouterCase(
      name: "Return in search moves into the results", key: .return, focus: .search,
      expected: .move(1)),
    KeyRouterCase(
      name: "Shift Return in search moves into the results", key: .return, modifiers: .shift,
      focus: .search, expected: .move(1)),
    KeyRouterCase(
      name: "Up in search is left to the field", key: .upArrow, focus: .search, expected: nil),
    KeyRouterCase(
      name: "Command F in search stays in search", key: KeyEquivalent("f"), modifiers: .command,
      focus: .search, expected: .focusSearch),
  ]

  static let list: [KeyRouterCase] = [
    KeyRouterCase(name: "Up moves up", key: .upArrow, focus: .list, expected: .move(-1)),
    KeyRouterCase(name: "Down moves down", key: .downArrow, focus: .list, expected: .move(1)),
    KeyRouterCase(
      name: "Shift Up extends up", key: .upArrow, modifiers: .shift, focus: .list,
      expected: .extend(-1)),
    KeyRouterCase(
      name: "Shift Down extends down", key: .downArrow, modifiers: .shift, focus: .list,
      expected: .extend(1)),
    KeyRouterCase(name: "Return edits", key: .return, focus: .list, expected: .edit),
    KeyRouterCase(
      name: "Command Return toggles done", key: .return, modifiers: .command, focus: .list,
      expected: .toggleDone),
    KeyRouterCase(
      name: "Command C copies", key: KeyEquivalent("c"), modifiers: .command, focus: .list,
      expected: .copy),
    KeyRouterCase(
      name: "Shift Command C copies the path", key: KeyEquivalent("c"),
      modifiers: [.command, .shift], focus: .list, expected: .copyPath),
    KeyRouterCase(name: "Space previews", key: .space, focus: .list, expected: .preview),
    KeyRouterCase(
      name: "Command O opens the source", key: KeyEquivalent("o"), modifiers: .command,
      focus: .list, expected: .openSource),
    KeyRouterCase(
      name: "Command R shows in Finder", key: KeyEquivalent("r"), modifiers: .command,
      focus: .list, expected: .showInFinder),
    KeyRouterCase(
      name: "Command Delete deletes", key: .delete, modifiers: .command, focus: .list,
      expected: .delete),
    KeyRouterCase(
      name: "Command K opens the actions menu", key: KeyEquivalent("k"), modifiers: .command,
      focus: .list, expected: .actionsMenu),
    KeyRouterCase(
      name: "Esc in the list goes back to the input", key: .escape, focus: .list,
      expected: .backToInput),
    KeyRouterCase(
      name: "Command F in the list jumps to search", key: KeyEquivalent("f"),
      modifiers: .command, focus: .list, expected: .focusSearch),
    KeyRouterCase(
      name: "Delete alone does nothing", key: .delete, focus: .list, characters: "\u{7F}",
      expected: nil),
    KeyRouterCase(
      name: "A letter types into the input", key: KeyEquivalent("a"), focus: .list,
      characters: "a", expected: .type("a")),
    KeyRouterCase(
      name: "Shift keeps the case of a typed letter", key: KeyEquivalent("a"),
      modifiers: .shift, focus: .list, characters: "A", expected: .type("A")),
    KeyRouterCase(
      name: "Option types the glyph it makes", key: KeyEquivalent("a"), modifiers: .option,
      focus: .list, characters: "å", expected: .type("å")),
    KeyRouterCase(
      name: "A digit types", key: KeyEquivalent("1"), focus: .list, characters: "1",
      expected: .type("1")),
    KeyRouterCase(
      name: "Shift and a symbol types the symbol", key: KeyEquivalent("1"), modifiers: .shift,
      focus: .list, characters: "!", expected: .type("!")),
    KeyRouterCase(
      name: "Command with a free letter does not type", key: KeyEquivalent("j"),
      modifiers: .command, focus: .list, characters: "j", expected: nil),
    KeyRouterCase(
      name: "Control with a letter does not type", key: KeyEquivalent("a"), modifiers: .control,
      focus: .list, characters: "\u{1}", expected: nil),
    KeyRouterCase(
      name: "Tab does not type", key: .tab, focus: .list, characters: "\t", expected: nil),
    KeyRouterCase(
      name: "Forward delete does not type", key: KeyEquivalent("\u{F728}"), focus: .list,
      characters: "\u{F728}", expected: nil),
    KeyRouterCase(
      name: "A function key does not type", key: KeyEquivalent("\u{F708}"), focus: .list,
      characters: "\u{F708}", expected: nil),
    KeyRouterCase(
      name: "Shift Space does not type", key: .space, modifiers: .shift, focus: .list,
      characters: " ", expected: nil),
    KeyRouterCase(
      name: "Shift Return does not type", key: .return, modifiers: .shift, focus: .list,
      characters: "\r", expected: nil),
  ]

  static let edit: [KeyRouterCase] = [
    KeyRouterCase(name: "Return in an edit saves", key: .return, focus: .edit, expected: .saveEdit),
    KeyRouterCase(
      name: "Shift Return in an edit adds a line", key: .return, modifiers: .shift, focus: .edit,
      expected: nil),
    KeyRouterCase(
      name: "Esc in an edit cancels", key: .escape, focus: .edit, expected: .cancelEdit),
    KeyRouterCase(
      name: "Command F in an edit is left to the field", key: KeyEquivalent("f"),
      modifiers: .command, focus: .edit, expected: nil),
    KeyRouterCase(
      name: "Up in an edit is left to the field", key: .upArrow, focus: .edit, expected: nil),
    KeyRouterCase(
      name: "Down in an edit is left to the field", key: .downArrow, focus: .edit, expected: nil),
    KeyRouterCase(
      name: "Command V in an edit is left to the field", key: KeyEquivalent("v"),
      modifiers: .command, focus: .edit, expected: nil),
    KeyRouterCase(
      name: "Command C in an edit is left to the field", key: KeyEquivalent("c"),
      modifiers: .command, focus: .edit, expected: nil),
    KeyRouterCase(
      name: "Space in an edit is left to the field", key: .space, focus: .edit, expected: nil),
  ]

  static let menu: [KeyRouterCase] = [
    KeyRouterCase(
      name: "Down in the menu moves the highlight", key: .downArrow, focus: .menu,
      expected: .menuMove(1)),
    KeyRouterCase(
      name: "Up in the menu moves the highlight", key: .upArrow, focus: .menu,
      expected: .menuMove(-1)),
    KeyRouterCase(
      name: "Return in the menu runs the item", key: .return, focus: .menu, expected: .menuRun),
    KeyRouterCase(
      name: "Esc in the menu closes it", key: .escape, focus: .menu, expected: .menuClose),
    KeyRouterCase(
      name: "Command K in the menu closes it", key: KeyEquivalent("k"), modifiers: .command,
      focus: .menu, expected: .menuClose),
    KeyRouterCase(
      name: "Command F in the menu is left to the field", key: KeyEquivalent("f"),
      modifiers: .command, focus: .menu, expected: nil),
    KeyRouterCase(
      name: "Typing in the menu is left to the field", key: KeyEquivalent("m"), focus: .menu,
      characters: "m", expected: nil),
    KeyRouterCase(
      name: "Space in the menu is left to the field", key: .space, focus: .menu, expected: nil),
    KeyRouterCase(name: "Tab in the menu does nothing", key: .tab, focus: .menu, expected: .ignore),
    KeyRouterCase(
      name: "Shift Tab in the menu does nothing", key: .tab, modifiers: .shift, focus: .menu,
      expected: .ignore),
  ]

  static let openMenu: [KeyRouterCase] = [Focus.search, .list, .input, .edit].flatMap { focus in
    [
      KeyRouterCase(
        name: "Up with the menu open and \(focus) focused moves the highlight", key: .upArrow,
        focus: focus, menuIsOpen: true, expected: .menuMove(-1)),
      KeyRouterCase(
        name: "Down with the menu open and \(focus) focused moves the highlight",
        key: .downArrow, focus: focus, menuIsOpen: true, expected: .menuMove(1)),
      KeyRouterCase(
        name: "Return with the menu open and \(focus) focused runs the item", key: .return,
        focus: focus, menuIsOpen: true, expected: .menuRun),
      KeyRouterCase(
        name: "Esc with the menu open and \(focus) focused closes it", key: .escape,
        focus: focus, menuIsOpen: true, expected: .menuClose),
      KeyRouterCase(
        name: "Command K with the menu open and \(focus) focused closes it",
        key: KeyEquivalent("k"), modifiers: .command, focus: focus, menuIsOpen: true,
        expected: .menuClose),
      KeyRouterCase(
        name: "Command F with the menu open and \(focus) focused is left to the field",
        key: KeyEquivalent("f"), modifiers: .command, focus: focus, menuIsOpen: true,
        expected: nil),
      KeyRouterCase(
        name: "Tab with the menu open and \(focus) focused does nothing", key: .tab,
        focus: focus, menuIsOpen: true, expected: .ignore),
      KeyRouterCase(
        name: "Shift Tab with the menu open and \(focus) focused does nothing", key: .tab,
        modifiers: .shift, focus: focus, menuIsOpen: true, expected: .ignore),
    ]
  }
}

struct KeyRouterTests {
  @Test(arguments: KeyRouterCases.all)
  func mapsKey(_ c: KeyRouterCase) {
    let command = KeyRouter.command(
      for: KeyStroke(key: c.key, modifiers: c.modifiers, characters: c.characters), focus: c.focus,
      menuIsOpen: c.menuIsOpen, inputIsEmpty: c.inputIsEmpty, hasAttachment: c.hasAttachment)
    #expect(command == c.expected)
  }

  @Test func keyEventsBecomeKeyStrokes() throws {
    func event(_ code: UInt16, _ typed: String, _ flags: NSEvent.ModifierFlags) throws -> NSEvent {
      try #require(
        NSEvent.keyEvent(
          with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
          context: nil, characters: typed, charactersIgnoringModifiers: typed.lowercased(),
          isARepeat: false, keyCode: code))
    }
    let copyPath = try #require(KeyStroke(event: event(8, "C", [.command, .shift])))
    #expect(
      copyPath
        == KeyStroke(key: KeyEquivalent("c"), modifiers: [.command, .shift], characters: "C"))
    let up = try #require(KeyStroke(event: event(126, "\u{F700}", [.numericPad, .function])))
    #expect(up == KeyStroke(key: .upArrow, modifiers: [], characters: "\u{F700}"))
    let enter = try #require(KeyStroke(event: event(76, "\u{3}", [.numericPad])))
    #expect(enter == KeyStroke(key: .return, modifiers: [], characters: "\u{3}"))
    let backTab = try #require(KeyStroke(event: event(48, "\u{19}", [.shift])))
    #expect(backTab == KeyStroke(key: .tab, modifiers: .shift, characters: "\u{19}"))
  }
}

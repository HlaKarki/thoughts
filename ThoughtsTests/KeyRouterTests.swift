import AppKit
import SwiftUI
import Testing

@testable import Thoughts

struct KeyRouterCase: Sendable, CustomTestStringConvertible {
  let name: String
  let key: KeyEquivalent
  var modifiers: EventModifiers = []
  var focus: Focus = .input
  var inputIsEmpty = true
  var hasAttachment = false
  let expected: KeyCommand?

  var testDescription: String { name }
}

enum KeyRouterCases {
  static let all: [KeyRouterCase] = input + search + list

  static let input: [KeyRouterCase] = [
    KeyRouterCase(name: "Return in the input adds", key: .return, expected: .add),
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
      name: "Typing a letter is left to the field", key: KeyEquivalent("a"), expected: nil),
  ]

  static let search: [KeyRouterCase] = [
    KeyRouterCase(
      name: "Esc in search clears it", key: .escape, focus: .search, expected: .clearSearch),
    KeyRouterCase(
      name: "Down in search moves into the results", key: .downArrow, focus: .search,
      expected: .move(1)),
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
    KeyRouterCase(name: "Delete alone does nothing", key: .delete, focus: .list, expected: nil),
  ]
}

struct KeyRouterTests {
  @Test(arguments: KeyRouterCases.all)
  func mapsKey(_ c: KeyRouterCase) {
    let command = KeyRouter.command(
      for: KeyStroke(key: c.key, modifiers: c.modifiers), focus: c.focus,
      inputIsEmpty: c.inputIsEmpty, hasAttachment: c.hasAttachment)
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
    #expect(copyPath == KeyStroke(key: KeyEquivalent("c"), modifiers: [.command, .shift]))
    let up = try #require(KeyStroke(event: event(126, "\u{F700}", [.numericPad, .function])))
    #expect(up == KeyStroke(key: .upArrow, modifiers: []))
    let enter = try #require(KeyStroke(event: event(76, "\u{3}", [.numericPad])))
    #expect(enter == KeyStroke(key: .return, modifiers: []))
  }
}

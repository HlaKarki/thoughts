import AppKit
import Testing

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct PanelKeyEquivalentTests {
  static func event(_ key: String, _ flags: NSEvent.ModifierFlags, code: UInt16, window: Int) throws
    -> NSEvent
  {
    try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
        windowNumber: window, context: nil, characters: key, charactersIgnoringModifiers: key,
        isARepeat: false, keyCode: code))
  }

  @Test func commandVInTheInputReachesThePasteHandler() throws {
    let rig = try InputFocusTests.rig()
    let board = Throwaway.pasteboard()
    rig.panel.pasteboard = board
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    var received: [NSPasteboard] = []
    rig.panel.onPaste = {
      received.append($0)
      return true
    }
    #expect(rig.panel.makeFirstResponder(rig.field))
    #expect(rig.panel.firstResponder is PasteFieldEditor)
    let paste = try Self.event("v", .command, code: 9, window: rig.panel.windowNumber)
    #expect(rig.panel.performKeyEquivalent(with: paste))
    #expect(received.count == 1)
    #expect(received.first === board)
    rig.panel.makeFirstResponder(nil)
  }

  @Test func commandAInTheEditFieldSelectsItsText() throws {
    let edit = EditTextView()
    edit.frame = NSRect(x: 0, y: 0, width: 300, height: 40)
    let panel = ThoughtsPanel(content: edit)
    edit.setText("Ask the team for the staging API key")
    #expect(panel.makeFirstResponder(edit))
    edit.setSelectedRange(NSRange(location: 0, length: 0))
    let selectAll = try Self.event("a", .command, code: 0, window: panel.windowNumber)
    #expect(panel.performKeyEquivalent(with: selectAll))
    #expect(edit.selectedRange() == NSRange(location: 0, length: (edit.string as NSString).length))
    panel.makeFirstResponder(nil)
  }

  @Test func theEditKeysMapToTheStandardActions() throws {
    func action(_ key: String, _ flags: NSEvent.ModifierFlags) throws -> Selector? {
      ThoughtsPanel.editAction(for: try Self.event(key, flags, code: 0, window: 0))
    }
    #expect(try action("x", .command) == Selector(("cut:")))
    #expect(try action("c", .command) == Selector(("copy:")))
    #expect(try action("v", .command) == Selector(("paste:")))
    #expect(try action("a", .command) == Selector(("selectAll:")))
    #expect(try action("z", .command) == Selector(("undo:")))
    #expect(try action("z", [.command, .shift]) == Selector(("redo:")))
    #expect(try action("f", .command) == nil)
    #expect(try action("v", [.command, .option]) == nil)
    #expect(try action("v", []) == nil)
  }

  @Test func theEditKeysIgnoreCapsLockAndTheKeypadAndFunctionFlags() throws {
    func action(_ key: String, _ flags: NSEvent.ModifierFlags) throws -> Selector? {
      ThoughtsPanel.editAction(for: try Self.event(key, flags, code: 0, window: 0))
    }
    for extra: NSEvent.ModifierFlags in [.capsLock, .numericPad, .function] {
      #expect(try action("v", [.command, extra]) == Selector(("paste:")))
      #expect(try action("z", [.command, .shift, extra]) == Selector(("redo:")))
      #expect(try action("v", [.command, .option, extra]) == nil)
    }
  }

  @Test func commandZAndShiftCommandZUndoAndRedoTypingInTheEditField() throws {
    let edit = EditTextView()
    edit.frame = NSRect(x: 0, y: 0, width: 300, height: 40)
    let panel = ThoughtsPanel(content: edit)
    edit.setText("staging")
    #expect(panel.makeFirstResponder(edit))
    edit.setSelectedRange(NSRange(location: 7, length: 0))
    edit.insertText(" key", replacementRange: edit.selectedRange())
    #expect(edit.string == "staging key")
    let undo = try Self.event("z", .command, code: 6, window: panel.windowNumber)
    #expect(panel.performKeyEquivalent(with: undo))
    #expect(edit.string == "staging")
    let redo = try Self.event("z", [.command, .shift], code: 6, window: panel.windowNumber)
    #expect(panel.performKeyEquivalent(with: redo))
    #expect(edit.string == "staging key")
    panel.makeFirstResponder(nil)
  }

  @Test func otherKeysFallThroughToTheWindow() throws {
    let rig = try InputFocusTests.rig()
    let find = try Self.event("f", .command, code: 3, window: rig.panel.windowNumber)
    #expect(!rig.panel.performKeyEquivalent(with: find))
  }
}

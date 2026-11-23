import AppKit
import Testing

@testable import Thoughts

@MainActor
struct MainMenuTests {
  static func editItems() throws -> [NSMenuItem] {
    let menu = MainMenu.build()
    return try #require(menu.items.last?.submenu).items
  }

  @Test func theEditMenuHoldsTheStandardItemsOnTheirKeys() throws {
    let items = try Self.editItems()
    func item(_ action: Selector) -> NSMenuItem? { items.first { $0.action == action } }
    #expect(item(#selector(NSText.paste(_:)))?.keyEquivalent == "v")
    #expect(item(#selector(NSText.copy(_:)))?.keyEquivalent == "c")
    #expect(item(#selector(NSText.cut(_:)))?.keyEquivalent == "x")
    #expect(item(#selector(NSText.selectAll(_:)))?.keyEquivalent == "a")
    #expect(item(Selector(("undo:")))?.keyEquivalent == "z")
    let redo = item(Selector(("redo:")))
    #expect(redo?.keyEquivalent == "z")
    #expect(redo?.keyEquivalentModifierMask == [.command, .shift])
    for entry in items where entry.action != nil {
      #expect(entry.target == nil)
    }
    #expect(item(#selector(NSText.paste(_:)))?.keyEquivalentModifierMask == .command)
  }

  @Test func commandVThroughTheMainMenuReachesThePasteHandler() async throws {
    let rig = try InputFocusTests.rig()
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    rig.panel.pasteboard = board
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    var received: [NSPasteboard] = []
    rig.panel.onPaste = {
      received.append($0)
      return true
    }
    #expect(rig.panel.makeFirstResponder(rig.field))
    let editor = try #require(rig.panel.firstResponder as? PasteFieldEditor)
    let previous = NSApp.mainMenu
    NSApp.mainMenu = MainMenu.build()
    defer { NSApp.mainMenu = previous }
    let paste = try #require(
      NSApp.mainMenu?.items.last?.submenu?.items.first {
        $0.action == #selector(NSText.paste(_:))
      })
    paste.target = editor
    let event = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
        windowNumber: rig.panel.windowNumber, context: nil, characters: "v",
        charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9))
    #expect(NSApp.mainMenu?.performKeyEquivalent(with: event) == true)
    try await Task.sleep(for: .milliseconds(150))
    #expect(received.count == 1)
    #expect(received.first === board)
    rig.panel.makeFirstResponder(nil)
  }
}

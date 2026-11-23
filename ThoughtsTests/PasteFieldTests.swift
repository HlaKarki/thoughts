import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
struct PasteFieldTests {
  static func inputFields(in view: NSView) -> [InputTextField] {
    var found: [InputTextField] = []
    for sub in view.subviews {
      if let field = sub as? InputTextField { found.append(field) }
      found.append(contentsOf: inputFields(in: sub))
    }
    return found
  }

  @Test func pasteInTheInputFieldReachesThePanelHandler() throws {
    let fixture = try ListFixture()
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let hosting = NSHostingView(
      rootView: PanelRootView(
        preferences: Preferences(defaults: defaults), list: fixture.model, input: fixture.input))
    hosting.sizingOptions = []
    let panel = ThoughtsPanel(content: hosting)
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    panel.pasteboard = board
    var received: [NSPasteboard] = []
    panel.onPaste = {
      received.append($0)
      return true
    }
    panel.setContentSize(NSSize(width: 360, height: 812))
    hosting.layoutSubtreeIfNeeded()
    let input = try #require(Self.inputFields(in: hosting).first)
    #expect(panel.makeFirstResponder(input))
    let editor = try #require(panel.firstResponder as? PasteFieldEditor)
    editor.paste(nil)
    #expect(received.count == 1)
    #expect(received.first === board)
    panel.makeFirstResponder(nil)
  }
}

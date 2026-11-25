import AppKit
import SwiftUI
import Synchronization
import Testing

@testable import Thoughts

private final class PromisedData: NSObject, NSPasteboardItemDataProvider, Sendable {
  let asked = Mutex<[NSPasteboard.PasteboardType]>([])

  func pasteboard(
    _ pasteboard: NSPasteboard?, item: NSPasteboardItem,
    provideDataForType type: NSPasteboard.PasteboardType
  ) {
    asked.withLock { $0.append(type) }
    item.setString("promised text", forType: type)
  }
}

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
    panel.setContentSize(NSSize(width: PanelController.width, height: PanelController.maxHeight))
    hosting.layoutSubtreeIfNeeded()
    let input = try #require(Self.inputFields(in: hosting).first)
    #expect(panel.makeFirstResponder(input))
    let editor = try #require(panel.firstResponder as? PasteFieldEditor)
    editor.paste(nil)
    #expect(received.count == 1)
    #expect(received.first === board)
    panel.makeFirstResponder(nil)
  }

  @Test func thePasteItemIsCheckedWithoutReadingTheClipboard() throws {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    let editor = PasteFieldEditor()
    editor.pasteboard = board
    let item = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "")
    for type: NSPasteboard.PasteboardType in [.string, .png, .tiff, .fileURL] {
      board.clearContents()
      let promised = PromisedData()
      let entry = NSPasteboardItem()
      #expect(entry.setDataProvider(promised, forTypes: [type]))
      #expect(board.writeObjects([entry]))
      #expect(editor.validateUserInterfaceItem(item))
      #expect(promised.asked.withLock { $0 }.isEmpty)
    }
  }
}

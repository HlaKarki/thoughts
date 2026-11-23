import AppKit
import KeyboardShortcuts
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
struct RecorderFocusTests {
  @Test func focusKeepsTheShortcutWithinTheFieldAndUnselected() throws {
    let host = NSHostingView(rootView: ShortcutRecorder(for: .summon).padding(20))
    let window = NSWindow(
      contentRect: CGRect(x: 0, y: 0, width: 200, height: 70), styleMask: [.titled],
      backing: .buffered, defer: false)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    let recorder = try #require(Self.recorder(in: host))
    window.makeFirstResponder(recorder)
    window.update()
    RunLoop.main.run(mode: .default, before: Date())
    host.layoutSubtreeIfNeeded()
    window.update()
    let editor = try #require(recorder.currentEditor() as? NSTextView)
    let clip = try #require(editor.superview)
    #expect(editor.selectedRange().length == 0)
    #expect(clip !== recorder)
    #expect(editor.frame == CGRect(origin: .zero, size: clip.bounds.size))
    window.makeFirstResponder(nil)
  }

  private static func recorder(in view: NSView) -> KeyboardShortcuts.RecorderCocoa? {
    if let match = view as? KeyboardShortcuts.RecorderCocoa { return match }
    return view.subviews.lazy.compactMap { recorder(in: $0) }.first
  }
}

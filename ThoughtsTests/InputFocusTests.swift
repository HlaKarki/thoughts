import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
struct InputFocusTests {
  struct Rig {
    let fixture: ListFixture
    let panel: ThoughtsPanel
    let hosting: NSHostingView<PanelRootView>
    let field: InputTextField
  }

  static func rig() throws -> Rig {
    let fixture = try ListFixture()
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let hosting = NSHostingView(
      rootView: PanelRootView(
        preferences: Preferences(defaults: defaults), list: fixture.model, input: fixture.input))
    hosting.sizingOptions = []
    let panel = ThoughtsPanel(content: hosting)
    panel.setContentSize(NSSize(width: 360, height: 812))
    hosting.layoutSubtreeIfNeeded()
    let field = try #require(PasteFieldTests.inputFields(in: hosting).first)
    return Rig(fixture: fixture, panel: panel, hosting: hosting, field: field)
  }

  static func settle() async {
    try? await Task.sleep(for: .milliseconds(400))
  }

  @Test func leavingSearchWithEscapeReturnsTypingToTheInput() async throws {
    let rig = try Self.rig()
    #expect(rig.panel.makeFirstResponder(rig.field))
    rig.fixture.model.perform(.focusSearch)
    await Self.settle()
    #expect(rig.field.currentEditor() == nil)
    #expect(rig.panel.firstResponder is NSTextView)
    rig.fixture.model.query = "staging"
    rig.fixture.model.perform(.clearSearch)
    await Self.settle()
    #expect(rig.fixture.model.focus == .input)
    let editor = try #require(rig.field.currentEditor())
    #expect(rig.panel.firstResponder === editor)
    rig.panel.makeFirstResponder(nil)
  }

  @Test func theInputTakesFocusBackAfterTheListHadIt() async throws {
    let rig = try Self.rig()
    #expect(rig.panel.makeFirstResponder(rig.field))
    rig.fixture.model.focus = .list
    await Self.settle()
    rig.fixture.model.perform(.backToInput)
    await Self.settle()
    let editor = try #require(rig.field.currentEditor())
    #expect(rig.panel.firstResponder === editor)
    rig.panel.makeFirstResponder(nil)
  }

  @Test func textFieldsOfThePanelDoNotRegisterForDrags() async throws {
    let rig = try Self.rig()
    #expect(rig.panel.makeFirstResponder(rig.field))
    let input = try #require(rig.panel.firstResponder as? NSTextView)
    #expect(input.registeredDraggedTypes.isEmpty)
    rig.fixture.model.perform(.focusSearch)
    await Self.settle()
    let search = try #require(rig.panel.firstResponder as? NSTextView)
    #expect(search !== input)
    #expect(search.registeredDraggedTypes.isEmpty)
    let edit = EditTextView()
    #expect(edit.registeredDraggedTypes.isEmpty)
    rig.panel.makeFirstResponder(nil)
  }

  @Test func typingFromTheListAppendsToTheInputAtTheCaret() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let input = rig.fixture.input
    model.onCommand = { command in
      if case .type(let text) = command { input.text += text }
    }
    input.text = "ab"
    #expect(rig.panel.makeFirstResponder(rig.field))
    model.focus = .list
    await Self.settle()
    model.perform(.type("c"))
    await Self.settle()
    let editor = try #require(rig.field.currentEditor())
    #expect(rig.panel.firstResponder === editor)
    #expect(editor.string == "abc")
    #expect(editor.selectedRange == NSRange(location: 3, length: 0))
    rig.panel.makeFirstResponder(nil)
  }

  @Test func typingFromTheListAppendsToTheSearchAtTheCaret() async throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    model.query = "stag"
    model.focus = .list
    await Self.settle()
    model.perform(.type("i"))
    await Self.settle()
    let editor = try #require(rig.panel.firstResponder as? NSTextView)
    #expect(editor.string == "stagi")
    #expect(editor.selectedRange == NSRange(location: 5, length: 0))
    rig.panel.makeFirstResponder(nil)
  }
}

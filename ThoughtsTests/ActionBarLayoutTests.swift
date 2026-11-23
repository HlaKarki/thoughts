import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
struct ActionBarLayoutTests {
  struct Case: Sendable, CustomTestStringConvertible {
    let name: String
    let focus: Focus
    let hasEntries: Bool
    let inputIsEmpty: Bool
    let width: CGFloat
    let hints: [[String]]
    var testDescription: String { name }
  }

  nonisolated static let cases = [
    Case(
      name: "input with text and entries", focus: .input, hasEntries: true, inputIsEmpty: false,
      width: 360, hints: [["Add", "↵"], ["Search", "⌘F"], ["Hide", "esc"]]),
    Case(
      name: "input with text and no entries", focus: .input, hasEntries: false,
      inputIsEmpty: false, width: 360, hints: [["Add", "↵"], ["Hide", "esc"]]),
    Case(
      name: "empty input with entries", focus: .input, hasEntries: true, inputIsEmpty: true,
      width: 360, hints: [["Select", "↑"], ["Paste", "⌘V"], ["Search", "⌘F"], ["Hide", "esc"]]),
    Case(
      name: "empty input and no entries", focus: .input, hasEntries: false, inputIsEmpty: true,
      width: 360, hints: [["Paste", "⌘V"], ["Hide", "esc"]]),
    Case(
      name: "list", focus: .list, hasEntries: true, inputIsEmpty: true, width: 620,
      hints: [
        ["Copy", "⌘C"], ["Edit", "↵"], ["Done", "⌘↵"], ["Actions", "⌘K"], ["Back", "esc"],
      ]),
    Case(
      name: "edit", focus: .edit, hasEntries: true, inputIsEmpty: true, width: 360,
      hints: [["Save", "↵"], ["New line", "⇧↵"], ["Cancel", "esc"]]),
    Case(
      name: "menu", focus: .menu, hasEntries: true, inputIsEmpty: true, width: 360,
      hints: [["Run", "↵"], ["Close", "esc"]]),
    Case(
      name: "search", focus: .search, hasEntries: true, inputIsEmpty: true, width: 360,
      hints: [["Select", "↓"], ["Clear", "esc"]]),
  ]

  static let hintSpacing = 14

  @Test(arguments: cases)
  func everyHintKeepsItsFullWidthWhenTheBarHasRoom(_ item: Case) throws {
    let bar = ActionBar(
      focus: item.focus, hasEntries: item.hasEntries, inputIsEmpty: item.inputIsEmpty,
      hasAttachment: false)
    let actual = try Self.inkWidth(of: bar, width: item.width)
    let reference = HStack(spacing: CGFloat(Self.hintSpacing)) {
      ForEach(item.hints, id: \.self) { hint in
        KeyHint(label: LocalizedStringKey(hint[0]), key: hint[1])
      }
    }
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, alignment: .trailing)
    let expected = try Self.inkWidth(of: reference, width: item.width)
    #expect(abs(actual - expected) <= 2, "bar \(actual) px, reference \(expected) px")
  }

  @Test func aFeedbackLineKeepsItsFullWidth() throws {
    let text = "That image file isn't there anymore"
    func bar() -> ActionBar {
      ActionBar(
        focus: .input, hasEntries: true, inputIsEmpty: false, hasAttachment: false,
        feedback: Feedback(kind: .message, text: text))
    }
    let narrow = try Self.inkWidth(of: bar(), width: 360)
    let wide = try Self.inkWidth(of: bar(), width: 1200)
    #expect(narrow == wide)
  }

  private static func inkWidth(of view: some View, width: CGFloat) throws -> Int {
    let url = try SnapshotRenderer.render(
      view.padding(12), size: CGSize(width: width, height: 40), appearance: .aqua,
      name: "action-bar-layout-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: url) }
    let image = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
    let background = try #require(image.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB))
    var left = image.pixelsWide
    var right = -1
    for x in 0..<image.pixelsWide {
      for y in 0..<image.pixelsHigh {
        guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        let delta =
          abs(color.redComponent - background.redComponent)
          + abs(color.greenComponent - background.greenComponent)
          + abs(color.blueComponent - background.blueComponent)
        if delta > 0.05 {
          left = min(left, x)
          right = max(right, x)
          break
        }
      }
    }
    try #require(right >= left)
    return right - left
  }
}

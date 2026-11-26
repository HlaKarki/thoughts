import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
@Suite(.serialized, .throwaway)
struct PanelGrabAreaTests {
  static let height = PanelController.maxHeight

  static let grabbed: [(String, CGPoint)] = [
    ("the header above the search field", CGPoint(x: 180, y: height - 4)),
    ("between the search field and the more button", CGPoint(x: 312, y: height - 28)),
    ("empty space above the rows", CGPoint(x: 180, y: height - 84)),
    ("the list margin beside a row", CGPoint(x: 6, y: 108)),
    ("the composer margin beside the field", CGPoint(x: 6, y: 55)),
    ("the hint bar on the left", CGPoint(x: 40, y: 20)),
    ("the hint bar on the right", CGPoint(x: 330, y: 20)),
    ("the bottom margin", CGPoint(x: 180, y: 4)),
  ]

  static let kept: [(String, CGPoint)] = [
    ("the search text", CGPoint(x: 150, y: height - 28)),
    ("the search icon", CGPoint(x: 28, y: height - 28)),
    ("the more button", CGPoint(x: 332, y: height - 28)),
    ("a row", CGPoint(x: 180, y: 108)),
    ("the input field", CGPoint(x: 180, y: 55)),
  ]

  @Test func theEmptyPartsMoveThePanelAndRowsFieldsAndTheMoreButtonDoNot() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      for (name, point) in Self.grabbed {
        #expect(harness.panel.isGrabArea(atWindow: point), "\(name) at \(point) is not grab area")
      }
      for (name, point) in Self.kept {
        #expect(!harness.panel.isGrabArea(atWindow: point), "\(name) at \(point) is grab area")
      }
    }
  }

  @Test func outsideTheGrabCheckClicksReachTheViewsTheyReachedBefore() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      let content = try #require(harness.panel.contentView)
      for (name, point) in Self.grabbed + Self.kept {
        let hit = content.hitTest(content.superview?.convert(point, from: nil) ?? point)
        #expect(!(hit is PanelGrabView), "\(name) at \(point) hits the grab area")
      }
    }
  }

  @Test func nothingIsGrabAreaWhileTheActionsMenuIsOpen() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      await harness.press(.up)
      await harness.press(.character("k"), .command)
      #expect(harness.list.isMenuOpen)
      await harness.settle("after the menu opens")
      for (name, point) in Self.grabbed {
        #expect(!harness.panel.isGrabArea(atWindow: point), "\(name) at \(point) is grab area")
      }
    }
  }

  @Test func anEmptyListAndASearchWithNoMatchesAreGrabArea() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      let middle = CGPoint(x: 180, y: Self.height / 2)
      #expect(harness.panel.isGrabArea(atWindow: middle), "the empty list is not grab area")
      try harness.seed(["one"])
      harness.list.query = "zzzz"
      await harness.settle("after the search")
      #expect(harness.list.isSearching)
      #expect(harness.list.visible.isEmpty)
      #expect(harness.panel.isGrabArea(atWindow: middle), "no matches is not grab area")
    }
  }

  @Test func aShownPanelThatTakesADragMovesWithThePointerAndADragOnARowIsLeftAlone()
    async throws
  {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      let panel = harness.panel
      var ended = 0
      panel.onDragStart = { true }
      panel.onDragEnd = { ended += 1 }
      let start = panel.frame.origin
      let row = CGPoint(x: 180, y: 108)
      #expect(!panel.grabPanel(atWindow: row, pointer: .zero))
      #expect(!panel.dragPanel(to: CGPoint(x: 50, y: 50)))
      panel.endDrag()
      #expect(panel.frame.origin == start)
      let header = CGPoint(x: 180, y: Self.height - 4)
      #expect(panel.grabPanel(atWindow: header, pointer: CGPoint(x: 1000, y: 500)))
      #expect(panel.dragPanel(to: CGPoint(x: 1010, y: 480)))
      #expect(panel.frame.origin == CGPoint(x: start.x + 10, y: start.y - 20))
      panel.endDrag()
      #expect(ended == 1)
      panel.onDragStart = { false }
      #expect(!panel.grabPanel(atWindow: header, pointer: .zero))
    }
  }
}

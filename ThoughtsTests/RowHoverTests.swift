import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
struct RowHoverTests {
  static let rows = [
    ("a", CGRect(x: 12, y: 4, width: 336, height: 34)),
    ("b", CGRect(x: 12, y: 42, width: 336, height: 52)),
    ("c", CGRect(x: 12, y: 98, width: 336, height: 34)),
  ]

  static func hover() -> RowHover {
    let hover = RowHover()
    for (name, frame) in rows { hover.place(name, at: frame) }
    return hover
  }

  @Test func thePointerHoversTheRowUnderItAndTheGapBelongsToTheNearestRow() {
    let hover = Self.hover()
    #expect(hover.row == nil)
    hover.pointerMoved(to: CGPoint(x: 100, y: 60))
    #expect(hover.row == "b")
    hover.pointerMoved(to: CGPoint(x: 100, y: 39))
    #expect(hover.row == "a")
    hover.pointerMoved(to: CGPoint(x: 100, y: 40))
    #expect(hover.row == "b")
    hover.pointerMoved(to: CGPoint(x: 4, y: 60))
    #expect(hover.row == nil)
  }

  @Test func rowsMovingUnderAStillPointerMoveTheHover() {
    let hover = Self.hover()
    hover.pointerMoved(to: CGPoint(x: 100, y: 60))
    #expect(hover.row == "b")
    for (name, frame) in Self.rows { hover.place(name, at: frame.offsetBy(dx: 0, dy: -56)) }
    #expect(hover.row == "c")
    hover.place("c", at: nil)
    #expect(hover.row == nil)
  }

  @Test func theHoverClearsWhenThePointerLeavesOrSomethingCoversTheRow() {
    let hover = Self.hover()
    hover.pointerMoved(to: CGPoint(x: 100, y: 60))
    hover.pointerMoved(to: nil)
    #expect(hover.row == nil)
    hover.pointerMoved(to: CGPoint(x: 100, y: 60))
    hover.cover(CGRect(x: 12, y: 50, width: 336, height: 200))
    #expect(hover.row == nil)
    hover.cover(nil)
    #expect(hover.row == "b")
    hover.clear()
    #expect(hover.row == nil)
  }

  @Test func hoverLeavesTheSelectionAndFocusAloneAndHidesBehindTheMenuAndThePanel() throws {
    let fixture = try ListFixture()
    try fixture.addText("one", daysAgo: 3)
    try fixture.addText("two", daysAgo: 2)
    try fixture.addText("three", daysAgo: 1)
    try fixture.reload()
    let model = fixture.model
    model.panelDidShow()
    let names = model.visible.map(\.fileName)
    model.select(names[2], extend: false)
    model.focus = .list
    for (offset, name) in names.enumerated() {
      model.hover.place(name, at: Self.rows[offset].1)
    }
    model.hover.pointerMoved(to: CGPoint(x: 100, y: 60))
    #expect(model.hoveredRow == names[1])
    #expect(model.selection == [names[2]])
    #expect(model.focus == .list)
    model.perform(.actionsMenu)
    #expect(model.isMenuOpen)
    #expect(model.hoveredRow == nil)
    model.perform(.menuClose)
    #expect(model.hoveredRow == names[1])
    model.panelDidHide()
    #expect(model.hoveredRow == nil)
    #expect(model.hover.row == nil)
    #expect(model.selection == [names[2]])
  }

  @Test func listReportsCountOnlyWhileThePanelIsShownAndEveryShowStartsClear() throws {
    let fixture = try ListFixture()
    try fixture.addText("one", daysAgo: 3)
    try fixture.addText("two", daysAgo: 2)
    try fixture.addText("three", daysAgo: 1)
    try fixture.reload()
    let model = fixture.model
    let names = model.visible.map(\.fileName)
    for (offset, name) in names.enumerated() {
      model.hover.place(name, at: Self.rows[offset].1)
    }
    let pointer = CGPoint(x: 100, y: 60)
    model.listPointerMoved(to: pointer)
    #expect(model.hoveredRow == nil)
    model.panelDidShow()
    model.listPointerMoved(to: pointer)
    #expect(model.hoveredRow == names[1])
    model.panelDidHide()
    model.listPointerMoved(to: pointer)
    #expect(model.hoveredRow == nil)
    model.hover.pointerMoved(to: pointer)
    #expect(model.hoveredRow == names[1])
    model.panelDidShow()
    #expect(model.hoveredRow == nil)
    model.listPointerMoved(to: pointer)
    #expect(model.hoveredRow == names[1])
  }

  @Test func theMenuHighlightFollowsPointerMovesAndKeysButNotRowsMovingUnderAStillPointer()
    throws
  {
    let fixture = try ListFixture()
    try fixture.addText("one", daysAgo: 1)
    try fixture.reload()
    let model = fixture.model
    let name = try #require(model.visible.first?.fileName)
    model.select(name, extend: false)
    model.perform(.actionsMenu)
    let items = model.menuItems
    #expect(items.count >= 4)
    func place(shift: CGFloat) {
      for (offset, item) in items.enumerated() {
        model.placeMenuRow(
          item.id, at: CGRect(x: 6, y: 6 + 30 * CGFloat(offset) + shift, width: 240, height: 30))
      }
    }
    place(shift: 0)
    #expect(model.menuHighlight == 0)
    model.menuPointerMoved(to: CGPoint(x: 100, y: 6 + 30 * 2 + 15))
    #expect(model.menuHighlight == 2)
    model.perform(.menuMove(1))
    #expect(model.menuHighlight == 3)
    model.menuPointerMoved(to: CGPoint(x: 101, y: 6 + 30 * 2 + 15))
    #expect(model.menuHighlight == 2)
    model.perform(.menuMove(-1))
    #expect(model.menuHighlight == 1)
    place(shift: -30)
    #expect(model.menuHighlight == 1)
    model.menuPointerMoved(to: nil)
    #expect(model.menuHighlight == 1)
    model.menuPointerMoved(to: CGPoint(x: 100, y: 400))
    #expect(model.menuHighlight == 1)
    #expect(model.selection == [name])
    model.perform(.menuClose)
    model.menuPointerMoved(to: CGPoint(x: 100, y: 6 + 15))
    #expect(model.menuHighlight == 1)
  }

  @Test func theTrackerWatchesThePointerInAPanelThatIsNotKeyAndLetsClicksThrough() {
    let view = PointerTracker.TrackerView(frame: CGRect(x: 0, y: 0, width: 360, height: 600))
    let area = view.trackingAreas.first
    #expect(view.trackingAreas.count == 1)
    #expect(area?.owner === view)
    for option in [
      NSTrackingArea.Options.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect,
    ] {
      #expect(area?.options.contains(option) == true)
    }
    #expect(view.isFlipped)
    #expect(view.hitTest(CGPoint(x: 10, y: 10)) == nil)
    var seen: [CGPoint?] = []
    view.onMove = { seen.append($0) }
    view.track(windowPoint: CGPoint(x: 20, y: 590))
    view.track(windowPoint: nil)
    #expect(seen == [CGPoint(x: 20, y: 10), nil])
  }
}

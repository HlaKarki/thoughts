import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
@Suite(.serialized, .throwaway)
struct HoverPanelTests {
  static func listTracker(_ harness: PanelHarness) throws -> PointerTracker.TrackerView {
    try #require(
      PanelHarness.views(of: PointerTracker.TrackerView.self, in: harness.hosting).max {
        $0.frame.width < $1.frame.width
      })
  }

  static func rowRects(_ harness: PanelHarness) -> [String: CGRect] {
    let catchers = PanelHarness.views(of: RightClickCatcher.CatcherView.self, in: harness.hosting)
      .map { $0.convert($0.bounds, to: nil) }
      .filter { $0.width > 0 }
      .sorted { $0.maxY > $1.maxY }
    let names = harness.list.visible.map(\.fileName)
    let shown = names.suffix(catchers.count)
    return Dictionary(uniqueKeysWithValues: zip(shown, catchers))
  }

  static func center(_ rect: CGRect) -> CGPoint {
    CGPoint(x: rect.midX, y: rect.midY)
  }

  static func flatRender(
    _ harness: PanelHarness, _ name: String, appearance: NSAppearance.Name
  ) throws -> NSBitmapImageRep {
    let url = try harness.snapshot(name, appearance: appearance)
    let source = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
    let canvas = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: source.pixelsWide, pixelsHigh: source.pixelsHigh,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    canvas.size = source.size
    let context = try #require(NSGraphicsContext(bitmapImageRep: canvas))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
      NSColor.windowBackgroundColor.setFill()
      CGRect(origin: .zero, size: source.size).fill()
    }
    source.draw(
      in: CGRect(origin: .zero, size: source.size), from: .zero, operation: .sourceOver,
      fraction: 1, respectFlipped: false, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
    try #require(canvas.representation(using: .png, properties: [:])).write(to: url)
    return canvas
  }

  static func fill(of row: CGRect, in image: NSBitmapImageRep, harness: PanelHarness) throws
    -> [Double]
  {
    let local = harness.hosting.convert(row, from: nil)
    let top = harness.hosting.isFlipped ? local.midY : harness.hosting.bounds.height - local.midY
    let scale = SnapshotRenderer.scale
    let x = Int((local.minX + 3) * CGFloat(scale))
    let y = Int(top * CGFloat(scale))
    var sum = [0.0, 0.0, 0.0]
    for dx in -1...1 {
      for dy in -1...1 {
        let color = try #require(image.colorAt(x: x + dx, y: y + dy)?.usingColorSpace(.deviceRGB))
        sum[0] += color.redComponent
        sum[1] += color.greenComponent
        sum[2] += color.blueComponent
      }
    }
    return sum.map { $0 / 9 }
  }

  static func distance(_ a: [Double], _ b: [Double]) -> Double {
    zip(a, b).map { abs($0 - $1) }.max() ?? 0
  }

  static func luminance(_ color: [Double]) -> Double {
    0.2126 * color[0] + 0.7152 * color[1] + 0.0722 * color[2]
  }

  static func seedMixedRows(_ harness: PanelHarness) throws -> (
    plain: String, other: String, selected: String, multiLine: String, image: String
  ) {
    let fixture = harness.fixture
    let plain = try fixture.addText("Buy oat milk", daysAgo: 5)
    let selected = try fixture.addText("Call the bank about the card", daysAgo: 4)
    let multiLine = try fixture.addText(
      "Read the crash log in the sync folder\nexplain why the retry loop never stops\nthen cap it at 3 attempts",
      daysAgo: 3)
    let other = try fixture.addText("Pick up the dry cleaning", daysAgo: 2)
    let image = try fixture.addScreenshot(note: "Rename fetchUser before the PR", daysAgo: 1)
    try fixture.reload()
    return (
      plain.file.lastPathComponent, other.file.lastPathComponent,
      selected.file.lastPathComponent, multiLine.file.lastPathComponent,
      image.file.lastPathComponent
    )
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func theRowUnderThePointerShowsAFillLighterThanTheSelection(_ appearance: NSAppearance.Name)
    async throws
  {
    let tone = appearance == .aqua ? "light" : "dark"
    try await PanelHarness.run { harness in
      let names = try Self.seedMixedRows(harness)
      try await harness.show()
      harness.list.select(names.selected, extend: false)
      let focus = harness.list.focus
      await harness.settle("after selecting")
      let tracker = try Self.listTracker(harness)
      let rows = Self.rowRects(harness)
      #expect(rows.count == harness.list.visible.count)
      let plainRow = try #require(rows[names.plain])
      tracker.track(windowPoint: Self.center(plainRow))
      await harness.settle("after the pointer moved over a plain row")
      #expect(harness.list.hoveredRow == names.plain)
      #expect(harness.list.selection == [names.selected])
      #expect(harness.list.focus == focus)
      let hovered = try Self.flatRender(harness, "hover-plain-row-\(tone)", appearance: appearance)
      let hover = try Self.fill(of: plainRow, in: hovered, harness: harness)
      let plain = try Self.fill(of: try #require(rows[names.other]), in: hovered, harness: harness)
      let selection = try Self.fill(
        of: try #require(rows[names.selected]), in: hovered, harness: harness)
      #expect(Self.distance(hover, plain) >= 4.0 / 255, "\(tone): hover \(hover) plain \(plain)")
      #expect(
        Self.distance(hover, selection) >= 4.0 / 255,
        "\(tone): hover \(hover) selected \(selection)"
      )
      let (light, dark) = (Self.luminance(plain), Self.luminance(selection))
      let between =
        min(light, dark) < Self.luminance(hover) && Self.luminance(hover) < max(light, dark)
      #expect(between, "\(tone): the hover fill is not between plain and selected")

      tracker.track(windowPoint: Self.center(try #require(rows[names.selected])))
      await harness.settle("after the pointer moved over the selected row")
      #expect(harness.list.hoveredRow == names.selected)
      let onSelected = try Self.flatRender(
        harness, "hover-on-selected-row-\(tone)", appearance: appearance)
      let stillSelected = try Self.fill(
        of: try #require(rows[names.selected]), in: onSelected, harness: harness)
      #expect(Self.distance(stillSelected, selection) < 2.0 / 255)
      #expect(
        Self.distance(try Self.fill(of: plainRow, in: onSelected, harness: harness), plain) < 2.0
          / 255)

      for (name, label) in [(names.multiLine, "multiline"), (names.image, "image")] {
        let row = try #require(rows[name])
        tracker.track(windowPoint: CGPoint(x: row.midX, y: row.maxY - 4))
        await harness.settle("after the pointer moved over the \(label) row")
        #expect(harness.list.hoveredRow == name)
        let render = try Self.flatRender(
          harness, "hover-\(label)-row-\(tone)", appearance: appearance)
        #expect(
          Self.distance(try Self.fill(of: row, in: render, harness: harness), hover) < 2.0 / 255)
      }
      #expect(harness.list.selection == [names.selected])
      #expect(harness.list.focus == focus)
      #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
    }
  }

  @Test func theHoverFollowsAScrollUnderAStillPointerAndClearsOnLeaveAndHide() async throws {
    try await PanelHarness.run { harness in
      try harness.seed((1...40).map { "Thought number \($0)" })
      try await harness.show()
      let tracker = try Self.listTracker(harness)
      let before = Self.rowRects(harness)
      let names = harness.list.visible.map(\.fileName)
      let start = try #require(before[names[names.count - 3]])
      let pointer = Self.center(start)
      let superview = try #require(harness.hosting.superview)
      let hit = harness.hosting.hitTest(superview.convert(pointer, from: nil))
      #expect(!(hit is PointerTracker.TrackerView))
      tracker.track(windowPoint: pointer)
      await harness.settle("after the pointer moved")
      #expect(harness.list.hoveredRow == names[names.count - 3])
      let scroller = try #require(harness.listScroller)
      let clip = scroller.contentView
      let document = try #require(scroller.documentView)
      var origin = clip.bounds.origin
      origin.y += document.isFlipped ? -150 : 150
      clip.scroll(to: origin)
      scroller.reflectScrolledClipView(clip)
      await harness.settle("after scrolling under a still pointer")
      let after = Self.rowRects(harness)
      let under = after.first { $0.value.insetBy(dx: 0, dy: -2).contains(pointer) }?.key
      #expect(under != nil)
      #expect(under != names[names.count - 3])
      #expect(harness.list.hoveredRow == under)
      tracker.track(windowPoint: nil)
      await harness.settle("after the pointer left the list")
      #expect(harness.list.hoveredRow == nil)
      tracker.track(windowPoint: pointer)
      await harness.settle("after the pointer came back")
      #expect(harness.list.hoveredRow == under)
      harness.list.panelDidHide()
      #expect(harness.list.hoveredRow == nil)
      #expect(harness.list.selection.isEmpty)
    }
  }

  @Test func aPointerMoveDuringTheHideLeavesNoHoverOrMenuHighlightOnTheNextShow() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      let tracker = try Self.listTracker(harness)
      let names = harness.list.visible.map(\.fileName)
      let row = try #require(Self.rowRects(harness)[names[1]])
      harness.list.panelDidHide()
      tracker.track(windowPoint: Self.center(row))
      await harness.settle("after a pointer move during the hide")
      #expect(harness.list.hoveredRow == nil)
      #expect(harness.list.hover.row == nil)
      try await harness.show()
      #expect(harness.list.hoveredRow == nil)
      let shown = try #require(Self.rowRects(harness)[names[1]])
      tracker.track(windowPoint: Self.center(shown))
      await harness.settle("after a pointer move on the shown panel")
      #expect(harness.list.hoveredRow == names[1])

      await harness.press(.up)
      await harness.press(.character("k"), .command)
      await harness.press(.down)
      #expect(harness.list.menuHighlight == 1)
      let menu = try #require(
        PanelHarness.views(of: PointerTracker.TrackerView.self, in: harness.hosting).min {
          $0.frame.width < $1.frame.width
        })
      let third = menu.convert(CGPoint(x: 100, y: 6 + ActionsMenu.rowHeight * 2 + 15), to: nil)
      harness.list.panelDidHide()
      menu.track(windowPoint: third)
      await harness.settle("after a pointer move over the menu during the hide")
      #expect(harness.list.menuHighlight == 1)
      try await harness.show()
      await harness.press(.up)
      await harness.press(.character("k"), .command)
      #expect(harness.list.isMenuOpen)
      #expect(harness.list.menuHighlight == 0)
    }
  }

  @Test func movingThePointerOverAMenuRowMovesTheHighlightAndKeysStillMoveIt() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      await harness.press(.up)
      let selected = harness.list.selection
      await harness.press(.character("k"), .command)
      #expect(harness.list.isMenuOpen)
      #expect(harness.list.menuHighlight == 0)
      let trackers = PanelHarness.views(of: PointerTracker.TrackerView.self, in: harness.hosting)
      #expect(trackers.count == 2)
      let menu = try #require(trackers.min { $0.frame.width < $1.frame.width })
      let list = try Self.listTracker(harness)
      let items = harness.list.menuItems
      func point(_ row: Int, nudge: CGFloat = 0) -> CGPoint {
        let separators = items.prefix(row + 1).dropFirst().filter(\.destructive).count
        let y = 6 + ActionsMenu.rowHeight * CGFloat(row) + CGFloat(separators) + 15
        return menu.convert(CGPoint(x: 100 + nudge, y: y), to: nil)
      }
      list.track(windowPoint: point(2))
      menu.track(windowPoint: point(2))
      await harness.settle("after the pointer moved over the third menu row")
      #expect(harness.list.menuHighlight == 2)
      #expect(harness.list.hoveredRow == nil)
      await harness.press(.down)
      #expect(harness.list.menuHighlight == 3)
      menu.track(windowPoint: point(2, nudge: 1))
      await harness.settle("after the pointer moved inside the third row")
      #expect(harness.list.menuHighlight == 2)
      await harness.press(.up)
      #expect(harness.list.menuHighlight == 1)
      await harness.type("c")
      await harness.settle("after filtering under a still pointer")
      #expect(harness.list.menuHighlight == 0)
      menu.track(windowPoint: nil)
      #expect(harness.list.menuHighlight == 0)
      #expect(harness.list.isMenuOpen)
      #expect(harness.list.selection == selected)
    }
  }
}

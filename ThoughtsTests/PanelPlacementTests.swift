import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
struct PanelPlacementTests {
  static func visible(_ size: CGSize, dock: CGFloat = 0) -> CGRect {
    CGRect(x: 0, y: dock, width: size.width, height: size.height - 37 - dock)
  }

  @Test(arguments: PreviewPlacementTests.builtInSizes, [PanelEdge.right, .left])
  func theDefaultPanelIs640TallAndCenteredAtItsEdgeOnEveryBuiltInSize(
    _ size: CGSize, _ edge: PanelEdge
  ) {
    for dock: CGFloat in [0, 74] {
      let visible = Self.visible(size, dock: dock)
      let frame = PanelController.frame(in: visible, edge: edge)
      let label = "\(size) dock \(dock) \(edge)"
      #expect(frame.size == CGSize(width: 360, height: 640), "\(label): \(frame)")
      #expect(frame.midY == visible.midY, "\(label): \(frame)")
      #expect(visible.contains(frame), "\(label): \(frame) left \(visible)")
      switch edge {
      case .right: #expect(frame.maxX == visible.maxX - 16, "\(label): \(frame)")
      case .left: #expect(frame.minX == visible.minX + 16, "\(label): \(frame)")
      }
    }
  }

  @Test(arguments: [CGFloat(671), 600, 432])
  func aScreenShorterThan672GivesAPanel32ShorterThanItsVisibleFrame(_ height: CGFloat) {
    let visible = CGRect(x: 0, y: 25, width: 1440, height: height)
    for edge in [PanelEdge.right, .left] {
      let frame = PanelController.frame(in: visible, edge: edge)
      #expect(frame.height == height - 32)
      #expect(frame.minY == visible.minY + 16)
      #expect(frame.maxY == visible.maxY - 16)
      #expect(frame.width == 360)
    }
    let roomy = CGRect(x: 0, y: 25, width: 1440, height: 672)
    #expect(PanelController.frame(in: roomy, edge: .right).height == 640)
  }

  static let screen = visible(CGSize(width: 1728, height: 1117))
  static let size = CGSize(width: 360, height: 640)

  static func at(x: CGFloat, y: CGFloat) -> CGRect {
    CGRect(origin: CGPoint(x: x, y: y), size: size)
  }

  @Test func aDropWithin40PointsOfAnEdgeSnaps16PointsInAndADropFartherAwayStays() {
    let visible = Self.screen
    let middle = (visible.midX - 180, visible.midY - 320)
    func dropped(_ x: CGFloat, _ y: CGFloat) -> CGRect {
      PanelController.dropped(Self.at(x: x, y: y), in: visible)
    }
    let left = visible.minX + 16
    let right = visible.maxX - 16 - 360
    let bottom = visible.minY + 16
    let top = visible.maxY - 16 - 640
    #expect(dropped(visible.minX + 30, middle.1) == Self.at(x: left, y: middle.1))
    #expect(dropped(visible.minX + 40, middle.1) == Self.at(x: left, y: middle.1))
    #expect(dropped(visible.minX + 41, middle.1) == Self.at(x: visible.minX + 41, y: middle.1))
    #expect(dropped(visible.maxX - 360 - 25, middle.1) == Self.at(x: right, y: middle.1))
    #expect(dropped(visible.maxX - 360 - 41, middle.1) == Self.at(x: right - 25, y: middle.1))
    #expect(dropped(middle.0, visible.minY + 3) == Self.at(x: middle.0, y: bottom))
    #expect(dropped(middle.0, visible.minY + 41) == Self.at(x: middle.0, y: visible.minY + 41))
    #expect(dropped(middle.0, visible.maxY - 640 - 39) == Self.at(x: middle.0, y: top))
    #expect(dropped(middle.0, visible.maxY - 640 - 41) == Self.at(x: middle.0, y: top - 25))
    #expect(dropped(middle.0, middle.1) == Self.at(x: middle.0, y: middle.1))
    #expect(dropped(visible.minX + 10, visible.maxY - 640 - 10) == Self.at(x: left, y: top))
    #expect(dropped(visible.minX + 10, visible.minY + 10) == Self.at(x: left, y: bottom))
    #expect(dropped(visible.maxX - 370, visible.maxY - 650) == Self.at(x: right, y: top))
    #expect(dropped(visible.maxX - 370, visible.minY + 10) == Self.at(x: right, y: bottom))
  }

  @Test func aDropPartlyOffTheScreenComesBackInside() {
    let visible = Self.screen
    for frame in [
      Self.at(x: visible.minX - 200, y: visible.midY - 320),
      Self.at(x: visible.maxX - 100, y: visible.midY - 320),
      Self.at(x: visible.midX, y: visible.minY - 300),
      Self.at(x: visible.midX, y: visible.maxY - 200),
      Self.at(x: visible.minX - 300, y: visible.maxY - 100),
      Self.at(x: visible.maxX - 10, y: visible.minY - 600),
    ] {
      let dropped = PanelController.dropped(frame, in: visible)
      #expect(visible.insetBy(dx: 16, dy: 16).contains(dropped), "\(frame) dropped at \(dropped)")
      #expect(dropped.size == Self.size)
    }
  }

  @Test func aDropFromATallerScreenKeepsItsTopAndTakesTheDropScreensHeight() {
    let short = CGRect(x: 0, y: 25, width: 1440, height: 600)
    let tall = CGRect(x: 400, y: 200, width: 360, height: 640)
    let dropped = PanelController.dropped(tall, in: short)
    #expect(dropped.height == 568)
    #expect(dropped.minY == short.minY + 16)
    #expect(dropped.maxY == short.maxY - 16)
    #expect(dropped.minX == 400)
  }

  @Test func aStoredSpotMapsInsideASmallerALargerAndAShortScreen() {
    let from = Self.screen
    let drops = [
      Self.at(x: from.midX - 180, y: from.midY - 320),
      Self.at(x: from.minX + 16, y: from.maxY - 656),
      Self.at(x: from.maxX - 376, y: from.minY + 16),
      Self.at(x: from.minX + 300, y: from.minY + 100),
      Self.at(x: from.maxX - 600, y: from.maxY - 700),
    ]
    let targets = [
      Self.visible(CGSize(width: 1312, height: 848)),
      Self.visible(CGSize(width: 3456, height: 2234), dock: 74),
      CGRect(x: -1440, y: 300, width: 1440, height: 500),
      CGRect(x: 1728, y: -400, width: 2056, height: 1292),
    ]
    for drop in drops {
      let position = PanelPosition(frame: drop, in: from)
      #expect(position.frame(size: Self.size, in: from) == drop)
      for target in targets {
        let size = PanelController.size(in: target)
        let mapped = position.frame(size: size, in: target)
        #expect(target.contains(mapped), "\(drop) mapped to \(mapped) leaves \(target)")
        #expect(mapped.size == size)
        #expect(
          PanelController.side(of: mapped, in: target) == PanelController.side(of: drop, in: from))
      }
    }
  }

  @Test func aSpotAtASideOrTheTopStaysThereOnAnyScreen() {
    let from = Self.screen
    let corner = PanelPosition(frame: Self.at(x: from.maxX - 376, y: from.maxY - 656), in: from)
    #expect(corner == PanelPosition(x: .end, y: .end))
    let side = PanelPosition(frame: Self.at(x: from.minX + 16, y: from.midY), in: from)
    #expect(side.x == .start)
    for target in [
      Self.visible(CGSize(width: 1312, height: 848)),
      Self.visible(CGSize(width: 3456, height: 2234)),
    ] {
      let mapped = corner.frame(size: PanelController.size(in: target), in: target)
      #expect(mapped.maxX == target.maxX - 16)
      #expect(mapped.maxY == target.maxY - 16)
      #expect(side.frame(size: Self.size, in: target).minX == target.minX + 16)
    }
    let short = CGRect(x: 0, y: 25, width: 1440, height: 600)
    let fill = PanelController.dropped(Self.at(x: 500, y: 0), in: short)
    let stored = PanelPosition(frame: fill, in: short)
    #expect(stored.y == .fraction(0.5))
    #expect(stored.frame(size: Self.size, in: from).midY == from.midY)
  }

  @Test func thePanelEdgeIsTheSideNearestThePanelsCenter() {
    let visible = Self.screen
    let leftHalf = Self.at(x: visible.midX - 181, y: 100)
    let rightHalf = Self.at(x: visible.midX - 179, y: 100)
    let middle = Self.at(x: visible.midX - 180, y: 100)
    for current in [PanelEdge.left, .right] {
      #expect(PanelController.edge(of: leftHalf, in: visible, current: current) == .left)
      #expect(PanelController.edge(of: rightHalf, in: visible, current: current) == .right)
      #expect(PanelController.edge(of: middle, in: visible, current: current) == current)
    }
    #expect(PanelPosition(frame: leftHalf, in: visible).side == .left)
    #expect(PanelPosition(frame: rightHalf, in: visible).side == .right)
    #expect(PanelPosition(frame: middle, in: visible).side == nil)
  }

  @Test func onlyAPanelAtASideEdgesInsetSlides() {
    let visible = Self.screen
    for edge in [PanelEdge.left, .right] {
      #expect(
        PanelController.slideEdge(
          of: PanelController.frame(in: visible, edge: .left), in: visible, preferring: edge)
          == .left)
      #expect(
        PanelController.slideEdge(
          of: PanelController.frame(in: visible, edge: .right), in: visible, preferring: edge)
          == .right)
      #expect(
        PanelController.slideEdge(
          of: Self.at(x: visible.minX + 17, y: 100), in: visible, preferring: edge) == nil)
      #expect(
        PanelController.slideEdge(
          of: Self.at(x: visible.midX, y: visible.minY + 16), in: visible, preferring: edge)
          == nil)
    }
    let narrow = CGRect(x: 0, y: 0, width: 392, height: 800)
    let both = Self.at(x: 16, y: 100)
    #expect(PanelController.slideEdge(of: both, in: narrow, preferring: .left) == .left)
    #expect(PanelController.slideEdge(of: both, in: narrow, preferring: .right) == .right)
  }

  static let external: ScreenFrames = (
    CGRect(x: 0, y: 0, width: 2560, height: 1440), CGRect(x: 0, y: 0, width: 2560, height: 1409)
  )
  static let builtIn: ScreenFrames = (
    CGRect(x: 2560, y: 166, width: 1728, height: 1117),
    CGRect(x: 2560, y: 166, width: 1728, height: 1085)
  )

  static func spot(_ x: PanelPosition.Place, _ y: PanelPosition.Place, on screen: ScreenFrames)
    -> CGRect
  {
    PanelPosition(x: x, y: y).frame(
      size: PanelController.size(in: screen.visible), in: screen.visible)
  }

  static func slides(
    _ x: PanelPosition.Place, _ y: PanelPosition.Place, on screen: ScreenFrames,
    among screens: [ScreenFrames]
  ) -> [PanelEdge?] {
    [PanelEdge.left, .right].map {
      PanelController.slideEdge(
        of: spot(x, y, on: screen), in: screen.visible, preferring: $0, among: screens)
    }
  }

  @Test func onHlasTwoDisplaysAPanelSlidesOnlyThroughAnEdgeWithNoDisplayBeyondIt() {
    let external = Self.external
    let builtIn = Self.builtIn
    let both = [external, builtIn]
    #expect(Self.spot(.end, .end, on: external).maxY == 1393)
    for y: PanelPosition.Place in [.end, .fraction(0.5), .start] {
      #expect(Self.slides(.end, y, on: external, among: both) == [nil, nil], "\(y)")
      #expect(Self.slides(.start, y, on: external, among: both) == [.left, .left], "\(y)")
      #expect(Self.slides(.end, y, on: builtIn, among: both) == [.right, .right], "\(y)")
      #expect(Self.slides(.start, y, on: builtIn, among: both) == [nil, nil], "\(y)")
      for alone in both {
        #expect(Self.slides(.end, y, on: alone, among: [alone]) == [.right, .right])
        #expect(Self.slides(.start, y, on: alone, among: [alone]) == [.left, .left])
      }
    }
  }

  @Test func aDisplayAboveStopsASideSlideOnlyWhereTheOffscreenFrameTouchesIt() {
    let main: ScreenFrames = (
      CGRect(x: 0, y: 0, width: 1728, height: 1117), CGRect(x: 0, y: 0, width: 1728, height: 1080)
    )
    let above: ScreenFrames = (
      CGRect(x: -400, y: 1117, width: 2560, height: 1440),
      CGRect(x: -400, y: 1117, width: 2560, height: 1409)
    )
    for y: PanelPosition.Place in [.end, .fraction(0.5), .start] {
      #expect(Self.slides(.end, y, on: main, among: [main, above]) == [.right, .right])
      #expect(Self.slides(.start, y, on: main, among: [main, above]) == [.left, .left])
    }
    let aboveRight: ScreenFrames = (
      CGRect(x: 1728, y: 1000, width: 1920, height: 1080),
      CGRect(x: 1728, y: 1000, width: 1920, height: 1049)
    )
    let screens = [main, above, aboveRight]
    #expect(Self.spot(.end, .end, on: main).maxY > aboveRight.frame.minY)
    #expect(Self.slides(.end, .end, on: main, among: screens) == [nil, nil])
    #expect(Self.spot(.end, .fraction(0.5), on: main).maxY < aboveRight.frame.minY)
    #expect(Self.slides(.end, .fraction(0.5), on: main, among: screens) == [.right, .right])
    #expect(Self.slides(.end, .start, on: main, among: screens) == [.right, .right])
    #expect(Self.slides(.start, .end, on: main, among: screens) == [.left, .left])
  }

  @Test func onHlasTwoDisplaysAChipSlidesUnlessItsSlidFrameTouchesTheOtherDisplay() {
    let both = [Self.external, Self.builtIn]
    let size = ChipSurface<EmptyView>.size
    func slides(_ edge: PanelEdge, on screen: ScreenFrames) -> Bool {
      let window = EdgeChipPanel.frames(size: size, visible: screen.visible, edge: edge).window
      let slid = EdgeChipPanel.slid(window, toward: edge, among: both)
      if let slid { #expect(slid == window.offsetBy(dx: edge == .right ? 24 : -24, dy: 0)) }
      return slid != nil
    }
    #expect(
      EdgeChipPanel.frames(size: size, visible: Self.external.visible, edge: .right).window.maxY
        < Self.builtIn.frame.minY)
    #expect(slides(.right, on: Self.external))
    #expect(slides(.left, on: Self.external))
    #expect(slides(.right, on: Self.builtIn))
    #expect(!slides(.left, on: Self.builtIn))
    let tallBuiltIn: ScreenFrames = (
      CGRect(x: 2560, y: 0, width: 1728, height: 1117),
      CGRect(x: 2560, y: 0, width: 1728, height: 1085)
    )
    let window = EdgeChipPanel.frames(size: size, visible: Self.external.visible, edge: .right)
      .window
    #expect(EdgeChipPanel.slid(window, toward: .right, among: [Self.external, tallBuiltIn]) == nil)
    #expect(EdgeChipPanel.slid(window, toward: .right, among: [Self.external]) != nil)
  }

  @Test func aPanelAtBothInsetsOfANarrowDisplayLeavesThroughTheOpenSide() {
    let narrow: ScreenFrames = (
      CGRect(x: 0, y: 0, width: 392, height: 800), CGRect(x: 0, y: 0, width: 392, height: 800)
    )
    let right: ScreenFrames = (
      CGRect(x: 392, y: 0, width: 1000, height: 800), CGRect(x: 392, y: 0, width: 1000, height: 800)
    )
    let left: ScreenFrames = (
      CGRect(x: -1000, y: 0, width: 1000, height: 800),
      CGRect(x: -1000, y: 0, width: 1000, height: 800)
    )
    #expect(Self.slides(.start, .end, on: narrow, among: [narrow]) == [.left, .right])
    #expect(Self.slides(.start, .end, on: narrow, among: [narrow, right]) == [.left, .left])
    #expect(Self.slides(.start, .end, on: narrow, among: [narrow, left]) == [.right, .right])
    #expect(Self.slides(.start, .end, on: narrow, among: [narrow, left, right]) == [nil, nil])
  }

  @Test func choosingAnEdgeMovesAFloatingPanelToThatSideAndKeepsItsTop() {
    let visible = Self.screen
    let floating = Self.at(x: visible.maxX - 700, y: 300)
    let moved = PanelController.moved(floating, to: .left, in: visible)
    #expect(moved == Self.at(x: visible.minX + 16, y: 300))
    #expect(PanelController.moved(floating, to: .right, in: visible) == floating)
    let high = Self.at(x: visible.midX + 100, y: visible.maxY - 656)
    #expect(PanelController.moved(high, to: .left, in: visible).maxY == visible.maxY - 16)
    let short = CGRect(x: 0, y: 25, width: 1440, height: 600)
    let tall = PanelController.moved(Self.at(x: 200, y: 0), to: .right, in: short)
    #expect(short.contains(tall))
    #expect(tall.maxY == short.maxY)
    #expect(tall.maxX == short.maxX - 16)
    let position = PanelPosition(frame: floating, in: visible)
    #expect(position.moved(to: .right) == position)
    #expect(position.moved(to: .left) == PanelPosition(x: .start, y: position.y))
  }

  @Test func aShownPanelSummonedOnAnotherScreenTakesItsStoredSpotThere() {
    let first = Self.screen
    let second = CGRect(x: 1728, y: 0, width: 2056, height: 1292)
    let position = PanelPosition(x: .fraction(0.25), y: .end)
    let onFirst = position.frame(size: Self.size, in: first)
    let plan = PanelController.showPlan(
      isShown: true, panelFrame: onFirst, requestedVisible: second, edge: .right,
      position: position)
    #expect(plan == .moveAndRefocus(position.frame(size: Self.size, in: second)))
    #expect(
      PanelController.showPlan(
        isShown: true, panelFrame: onFirst, requestedVisible: first, edge: .right,
        position: position) == .refocus)
  }
}

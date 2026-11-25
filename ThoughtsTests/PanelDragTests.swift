import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized)
struct PanelDragTests {
  typealias Rig = LiveEdgeTests.Rig

  static func shown(_ edge: PanelEdge = .right, reducesMotion: Bool = false) async throws -> Rig {
    let rig = try Rig(edge: edge, reducesMotion: reducesMotion)
    rig.preferences.keepOpen = false
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    #expect(
      await PanelHarness.waitUntil { rig.controller.frame == rig.panelFrame(edge) },
      "the panel never reached \(edge)")
    rig.controller.panel.contentView?.layoutSubtreeIfNeeded()
    return rig
  }

  static func headerPoint(of rig: Rig) -> CGPoint {
    CGPoint(x: PanelController.width / 2, y: rig.controller.frame.height - 4)
  }

  @discardableResult
  static func drag(_ rig: Rig, by offset: CGVector) -> Bool {
    let panel = rig.controller.panel
    let point = headerPoint(of: rig)
    let start = panel.convertPoint(toScreen: point)
    guard panel.grabPanel(atWindow: point, pointer: start) else { return false }
    for step in 1...4 {
      let share = CGFloat(step) / 4
      _ = panel.dragPanel(
        to: CGPoint(x: start.x + offset.dx * share, y: start.y + offset.dy * share))
    }
    panel.endDrag()
    return true
  }

  static func finish(_ rig: Rig) async {
    rig.controller.hide()
    rig.chip.hide()
    try? await Task.sleep(for: .milliseconds(400))
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  static func samples(_ rig: Rig, for duration: Duration) async -> [CGRect] {
    var frames: [CGRect] = []
    let end = ContinuousClock.now + duration
    while ContinuousClock.now < end {
      frames.append(rig.controller.frame)
      try? await Task.sleep(for: .milliseconds(10))
    }
    return frames
  }

  @Test func aDropInTheMiddleStaysWhereItWasLetGoAndIsStored() async throws {
    let rig = try await Self.shown()
    let start = rig.controller.frame
    let visible = rig.screen.visible
    let expected = start.offsetBy(dx: -500, dy: -120)
    #expect(PanelController.dropped(expected, in: visible) == expected)
    #expect(Self.drag(rig, by: CGVector(dx: -500, dy: -120)))
    #expect(rig.controller.frame == expected)
    #expect(rig.controller.restingFrame == expected)
    try? await Task.sleep(for: .milliseconds(300))
    #expect(rig.controller.frame == expected)
    #expect(rig.controller.isShown)
    #expect(rig.willHide == 0)
    #expect(rig.preferences.panelPosition == PanelPosition(frame: expected, in: visible))
    #expect(rig.preferences.edge == .right)
    #expect(rig.moves == 1)
    await Self.finish(rig)
  }

  @Test func aDropNearAnEdgeSnapsSixteenPointsIn() async throws {
    let rig = try await Self.shown()
    let start = rig.controller.frame
    let visible = rig.screen.visible
    let offset = CGVector(dx: -300, dy: visible.minY + 30 - start.minY)
    #expect(Self.drag(rig, by: offset))
    let expected = CGRect(
      x: start.minX - 300, y: visible.minY + 16, width: start.width, height: start.height)
    #expect(
      await PanelHarness.waitUntil { rig.controller.frame == expected },
      "the panel ended at \(rig.controller.frame)")
    #expect(rig.controller.restingFrame == expected)
    #expect(rig.preferences.panelPosition?.y == .start)
    await Self.finish(rig)
  }

  @Test(arguments: [false, true])
  func hideAndShowFadeInPlaceAwayFromASideEdgeAndKeepTheSpot(_ reducesMotion: Bool)
    async throws
  {
    let rig = try await Self.shown(reducesMotion: reducesMotion)
    #expect(Self.drag(rig, by: CGVector(dx: -500, dy: -120)))
    let spot = try #require(rig.controller.restingFrame)
    #expect(await PanelHarness.waitUntil { rig.controller.frame == spot })
    rig.controller.hide()
    let leaving = await Self.samples(rig, for: .milliseconds(300))
    #expect(leaving.allSatisfy { $0 == spot }, "the hide moved the panel: \(Set(leaving))")
    #expect(!rig.controller.isVisible)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    #expect(rig.controller.panel.alphaValue < 1)
    let arriving = await Self.samples(rig, for: .milliseconds(300))
    #expect(arriving.allSatisfy { $0 == spot }, "the show moved the panel: \(Set(arriving))")
    #expect(rig.controller.panel.alphaValue == 1)
    #expect(rig.controller.restingFrame == spot)
    await Self.finish(rig)
  }

  @Test func theStoredSpotSurvivesARelaunch() async throws {
    let rig = try await Self.shown()
    #expect(Self.drag(rig, by: CGVector(dx: -500, dy: -120)))
    let spot = try #require(rig.controller.restingFrame)
    let stored = try #require(rig.preferences.panelPosition)
    let relaunched = Preferences(defaults: rig.defaults)
    #expect(relaunched.panelPosition == stored)
    #expect(
      PanelController.frame(
        in: rig.screen.visible, edge: relaunched.edge, position: relaunched.panelPosition)
        == spot)
    await Self.finish(rig)
  }

  @Test func aDropAcrossTheMiddleChangesThePanelEdgeAtOnceWithoutMovingIt() async throws {
    let rig = try await Self.shown()
    let visible = rig.screen.visible
    let start = rig.controller.frame
    let dx = visible.minX + 300 - start.minX
    #expect(Self.drag(rig, by: CGVector(dx: dx, dy: 0)))
    #expect(rig.preferences.edge == .left)
    let spot = start.offsetBy(dx: dx, dy: 0)
    #expect(rig.controller.frame == spot)
    try? await Task.sleep(for: .milliseconds(400))
    #expect(rig.controller.frame == spot)
    #expect(rig.controller.restingFrame == spot)
    #expect(rig.preferences.edge == .left)
    await Self.finish(rig)
  }

  @Test func choosingAnEdgeMovesAFloatingPanelToThatSideAndKeepsItsTop() async throws {
    let rig = try await Self.shown()
    #expect(Self.drag(rig, by: CGVector(dx: -500, dy: -120)))
    let spot = try #require(rig.controller.restingFrame)
    rig.preferences.edge = .left
    let visible = rig.screen.visible
    let expected = CGRect(
      x: visible.minX + 16, y: spot.minY, width: spot.width, height: spot.height)
    #expect(
      await PanelHarness.waitUntil { rig.controller.frame == expected },
      "the panel ended at \(rig.controller.frame)")
    #expect(rig.controller.restingFrame == expected)
    #expect(rig.preferences.panelPosition == PanelPosition(frame: expected, in: visible))
    #expect(rig.preferences.panelPosition?.x == .start)
    rig.controller.hide()
    let gone = PanelController.offscreenFrame(from: expected, edge: .left)
    #expect(
      await PanelHarness.waitUntil { rig.controller.frame == gone },
      "a panel at the left side slides out, it left to \(rig.controller.frame)")
    await Self.finish(rig)
  }

  @Test func aClickThatDoesNotMoveLeavesThePanelAndTheStoredSpotAlone() async throws {
    let rig = try await Self.shown()
    let start = rig.controller.frame
    let panel = rig.controller.panel
    let point = Self.headerPoint(of: rig)
    let pointer = panel.convertPoint(toScreen: point)
    #expect(panel.grabPanel(atWindow: point, pointer: pointer))
    #expect(!panel.dragPanel(to: CGPoint(x: pointer.x + 2, y: pointer.y)))
    panel.endDrag()
    #expect(rig.controller.frame == start)
    #expect(rig.preferences.panelPosition == nil)
    #expect(rig.moves == 0)
    await Self.finish(rig)
  }

  @Test func aHiddenPanelTakesNoDrag() async throws {
    let rig = try await Self.shown()
    let point = Self.headerPoint(of: rig)
    rig.controller.hide()
    let panel = rig.controller.panel
    #expect(!panel.grabPanel(atWindow: point, pointer: panel.convertPoint(toScreen: point)))
    await Self.finish(rig)
  }

  @Test func aHideDuringADragStopsTheDragAndKeepsTheStoredSpot() async throws {
    let rig = try await Self.shown()
    let panel = rig.controller.panel
    let point = Self.headerPoint(of: rig)
    let pointer = panel.convertPoint(toScreen: point)
    #expect(panel.grabPanel(atWindow: point, pointer: pointer))
    #expect(panel.dragPanel(to: CGPoint(x: pointer.x - 400, y: pointer.y)))
    let midway = rig.controller.frame
    rig.controller.hide()
    #expect(!panel.dragPanel(to: CGPoint(x: pointer.x - 600, y: pointer.y)))
    panel.endDrag()
    let leaving = await Self.samples(rig, for: .milliseconds(300))
    #expect(leaving.allSatisfy { $0 == midway })
    #expect(rig.preferences.panelPosition == nil)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    #expect(
      await PanelHarness.waitUntil { rig.controller.frame == rig.panelFrame(.right) })
    await Self.finish(rig)
  }

  @Test func aChipShownWhileThePanelIsHiddenKeepsOffWhereThePanelWillShow() async throws {
    let rig = try await Self.shown()
    let visible = rig.screen.visible
    let start = rig.controller.frame
    #expect(Self.drag(rig, by: CGVector(dx: -100, dy: visible.minY + 20 - start.minY)))
    let spot = try #require(rig.controller.restingFrame)
    #expect(spot.minY == visible.minY + 16)
    #expect(await PanelHarness.waitUntil { rig.controller.frame == spot })
    rig.controller.hide()
    #expect(await PanelHarness.waitUntil { !rig.controller.isVisible })
    rig.chip.show(HintChipView(kind: .nothingToSave))
    #expect(await PanelHarness.waitUntil { rig.chip.windowAlpha == 1 })
    let chip = try #require(rig.chip.shownFrame)
    #expect(!rig.chip.windowFrame.intersects(spot), "\(rig.chip.windowFrame) covers \(spot)")
    #expect(visible.contains(rig.chip.windowFrame))
    rig.controller.show(inVisible: visible, makeKey: false)
    #expect(await PanelHarness.waitUntil { rig.controller.frame == spot })
    #expect(rig.chip.shownFrame == chip)
    await Self.finish(rig)
  }
}

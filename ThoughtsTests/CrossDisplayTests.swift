import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized, .throwaway)
struct CrossDisplayTests {
  typealias Rig = LiveEdgeTests.Rig
  typealias Sample = (frame: CGRect, alpha: CGFloat)

  static func aWideDisplayBesideALowerLaptop(builtInFirst: Bool = false) -> [ScreenFrames] {
    let union = NSScreen.screens.map(\.frame).reduce(CGRect.null) { $0.union($1) }
    let shift = union.maxX + 4000
    let both: [ScreenFrames] = [PanelPlacementTests.external, PanelPlacementTests.builtIn].map {
      ($0.frame.offsetBy(dx: shift, dy: 0), $0.visible.offsetBy(dx: shift, dy: 0))
    }
    return builtInFirst ? both.reversed() : both
  }

  static func samples(_ window: () -> Sample, until settled: () -> Bool) async -> [Sample] {
    var samples = [window()]
    let deadline = ContinuousClock.now + .seconds(5)
    while !settled(), ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(10))
      samples.append(window())
    }
    let tail = ContinuousClock.now + .milliseconds(150)
    while ContinuousClock.now < tail {
      try? await Task.sleep(for: .milliseconds(10))
      samples.append(window())
    }
    return samples
  }

  static func near(_ frame: CGRect?, _ target: CGRect) -> Bool {
    guard let frame else { return false }
    return frame.minX == target.minX && frame.size == target.size
      && abs(frame.minY - target.minY) < 1
  }

  static func still(_ samples: [Sample], at target: CGRect) -> Bool {
    samples.allSatisfy { $0.frame == samples[0].frame } && near(samples[0].frame, target)
  }

  @Test(arguments: [false, true], [PanelEdge.right, .left])
  func besideALowerLaptopDisplayThePanelAppearsAndDisappearsAtOnce(
    _ onBuiltIn: Bool, _ edge: PanelEdge
  ) throws {
    for reducesMotion in [false, true] {
      let rig = try Rig(
        edge: edge, reducesMotion: reducesMotion,
        screens: Self.aWideDisplayBesideALowerLaptop(builtInFirst: onBuiltIn))
      let target = rig.panelFrame(edge)
      rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
      #expect(Self.near(rig.controller.frame, target))
      #expect(rig.controller.panel.alphaValue == 1)
      #expect(rig.controller.restingFrame == target)
      rig.controller.hide()
      #expect(!rig.controller.isVisible)
      #expect(!rig.controller.isShown)
      #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
    }
  }

  @Test(arguments: [false, true])
  func aShownPanelCalledToTheOtherDisplayIsThereAtOnce(_ reducesMotion: Bool) throws {
    let displays = Self.aWideDisplayBesideALowerLaptop()
    let rig = try Rig(edge: .left, reducesMotion: reducesMotion, screens: displays)
    rig.controller.show(inVisible: displays[0].visible, makeKey: false)
    let moves = rig.moves
    let target = PanelController.frame(in: displays[1].visible, edge: .left)
    rig.controller.show(inVisible: displays[1].visible, makeKey: true)
    #expect(Self.near(rig.controller.frame, target))
    #expect(rig.controller.panel.alphaValue == 1)
    #expect(rig.key.made == 1)
    #expect(rig.controller.isKey)
    #expect(rig.controller.restingFrame == target)
    #expect(rig.moves == moves + 1)
    rig.controller.hide()
    #expect(!rig.controller.isVisible)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  static func chip(_ rig: Rig, settlesAt target: CGRect, alpha: CGFloat) async -> [Sample] {
    await samples(
      { (rig.chip.windowFrame, rig.chip.windowAlpha) },
      until: { rig.chip.windowFrame == target && rig.chip.windowAlpha == alpha })
  }

  @Test(arguments: [false, true], [PanelEdge.right, .left])
  func besideALowerLaptopDisplayAChipFadesInPlaceOnlyWhereItsSlideWouldTouchTheOtherDisplay(
    _ onBuiltIn: Bool, _ edge: PanelEdge
  ) async throws {
    let rig = try Rig(
      edge: edge, reducesMotion: false,
      screens: Self.aWideDisplayBesideALowerLaptop(builtInFirst: onBuiltIn))
    let fades = onBuiltIn && edge == .left
    let target = rig.chipFrames(edge).window
    rig.chip.show(HintChipView(kind: .nothingToSave))
    let shown = await Self.chip(rig, settlesAt: target, alpha: 1)
    #expect(shown.last?.frame == target)
    #expect(shown.last?.alpha == 1)
    #expect(shown.contains { $0.alpha < 1 })
    if fades {
      #expect(Self.still(shown, at: target), "the chip moved: \(shown.map(\.frame))")
    } else {
      #expect(shown.contains { $0.frame.minX != target.minX }, "the chip never slid in")
    }
    rig.chip.hide()
    let gone = fades ? target : target.offsetBy(dx: edge == .right ? 24 : -24, dy: 0)
    let hidden = await Self.chip(rig, settlesAt: gone, alpha: 0)
    #expect(hidden.last?.alpha == 0)
    if fades {
      #expect(Self.still(hidden, at: target), "the chip moved: \(hidden.map(\.frame))")
    } else {
      #expect(hidden.last?.frame == target.offsetBy(dx: edge == .right ? 24 : -24, dy: 0))
    }
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test(arguments: [false, true])
  func aChipFollowsThePanelToTheOtherDisplayWithoutCrossing(_ reducesMotion: Bool) async throws {
    let displays = Self.aWideDisplayBesideALowerLaptop()
    let rig = try Rig(edge: .left, reducesMotion: reducesMotion, screens: displays)
    rig.controller.show(inVisible: displays[0].visible, makeKey: false)
    #expect(await PanelHarness.waitUntil { Self.near(rig.controller.frame, rig.panelFrame(.left)) })
    rig.chip.show(HintChipView(kind: .nothingToSave))
    let start = rig.chipFrames(.left).window
    #expect(
      await PanelHarness.waitUntil { rig.chip.windowFrame == start && rig.chip.windowAlpha == 1 })
    let panel = PanelController.frame(in: displays[1].visible, edge: .left)
    let target = EdgeChipPanel.frames(
      size: ChipSurface<EmptyView>.size, visible: displays[1].visible, edge: .left, panel: panel
    ).window
    rig.controller.show(inVisible: displays[1].visible, makeKey: true)
    let moved = await Self.chip(rig, settlesAt: target, alpha: 1)
    #expect(
      moved.allSatisfy { $0.frame == start || $0.frame == target },
      "the chip crossed: \(moved.map(\.frame))")
    #expect(moved.last?.frame == target)
    #expect(moved.last?.alpha == 1)
    await rig.finish()
  }

  @Test(arguments: [false, true])
  func thePreviewJumpsToTheOtherDisplayWithThePanelAtOnce(_ reducesMotion: Bool) throws {
    let displays = Self.aWideDisplayBesideALowerLaptop()
    let rig = try Rig(edge: .left, reducesMotion: reducesMotion, screens: displays)
    rig.controller.show(inVisible: displays[0].visible, makeKey: false)
    rig.fixture.model.select(rig.shot.file.lastPathComponent, extend: false)
    rig.fixture.model.perform(.preview)
    #expect(Self.near(rig.preview.frame, try rig.previewFrame(.left)))
    #expect(rig.preview.alpha == 1)
    let panel = PanelController.frame(in: displays[1].visible, edge: .left)
    let target = try PreviewPlacementTests.expected(
      for: panel, edge: .left, in: displays[1].visible, fixture: rig.fixture)
    rig.controller.show(inVisible: displays[1].visible, makeKey: true)
    #expect(Self.near(rig.preview.frame, target))
    #expect(rig.preview.alpha == 1)
    rig.controller.hide()
    rig.preview.hide()
    #expect(!rig.preview.isVisible)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }
}

import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized)
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

  static func panel(_ rig: Rig, until settled: () -> Bool) async -> [Sample] {
    await samples({ (rig.controller.frame, rig.controller.panel.alphaValue) }, until: settled)
  }

  static func panel(_ rig: Rig, settlesAt target: CGRect) async -> [Sample] {
    await panel(rig) { near(rig.controller.frame, target) && rig.controller.panel.alphaValue == 1 }
  }

  static func panelHidden(_ rig: Rig) async -> [Sample] {
    await panel(rig) { !rig.controller.isVisible }
  }

  @Test(arguments: [false, true], [PanelEdge.right, .left])
  func besideALowerLaptopDisplayThePanelFadesInPlaceAtTheSharedEdgeAndSlidesAtAnOuterEdge(
    _ onBuiltIn: Bool, _ edge: PanelEdge
  ) async throws {
    let rig = try Rig(
      edge: edge, reducesMotion: false,
      screens: Self.aWideDisplayBesideALowerLaptop(builtInFirst: onBuiltIn))
    let fades = onBuiltIn == (edge == .left)
    let target = rig.panelFrame(edge)
    let gone = PanelController.offscreenFrame(from: target, edge: edge)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    let shown = await Self.panel(rig, settlesAt: target)
    #expect(Self.near(shown.last?.frame, target))
    #expect(shown.last?.alpha == 1)
    #expect(shown.contains { $0.alpha < 1 })
    #expect(shown.allSatisfy { $0.frame.minY == shown[0].frame.minY })
    if fades {
      #expect(Self.still(shown, at: target), "the panel moved: \(shown.map(\.frame))")
    } else {
      #expect(shown.contains { $0.frame.minX != target.minX }, "the panel never slid in")
    }
    rig.controller.hide()
    let hidden = await Self.panelHidden(rig)
    #expect(!rig.controller.isVisible)
    #expect(hidden.contains { $0.alpha < 1 })
    if fades {
      #expect(Self.still(hidden, at: target), "the panel moved: \(hidden.map(\.frame))")
    } else {
      #expect(Self.near(hidden.last?.frame, gone))
    }
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func aMainThreadStallRightAfterAShowOnlyDelaysTheFadeIn() async throws {
    let rig = try Rig(
      edge: .right, reducesMotion: false, screens: Self.aWideDisplayBesideALowerLaptop())
    let target = rig.panelFrame(.right)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    DispatchQueue.main.async { Thread.sleep(forTimeInterval: 0.45) }
    let shown = await Self.panel(rig, settlesAt: target)
    #expect(Self.still(shown, at: target), "the panel moved: \(shown.map(\.frame))")
    #expect(shown.contains { $0.alpha < 1 })
    #expect(shown.last?.alpha == 1)
    rig.controller.hide()
    #expect(await PanelHarness.waitUntil { !rig.controller.isVisible })
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test(arguments: [false, true], [PanelEdge.right, .left])
  func withReduceMotionThePanelFadesAtEveryEdgeOfAWideDisplayBesideALowerLaptop(
    _ onBuiltIn: Bool, _ edge: PanelEdge
  ) async throws {
    let rig = try Rig(
      edge: edge, reducesMotion: true,
      screens: Self.aWideDisplayBesideALowerLaptop(builtInFirst: onBuiltIn))
    let target = rig.panelFrame(edge)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    let shown = await Self.panel(rig, settlesAt: target)
    #expect(Self.still(shown, at: target))
    #expect(shown.last?.alpha == 1)
    rig.controller.hide()
    let hidden = await Self.panelHidden(rig)
    #expect(Self.still(hidden, at: target))
    #expect(!rig.controller.isVisible)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test(arguments: [false, true])
  func aShownPanelCalledToTheOtherDisplayFadesInThereWithoutCrossing(_ reducesMotion: Bool)
    async throws
  {
    let displays = Self.aWideDisplayBesideALowerLaptop()
    let rig = try Rig(edge: .left, reducesMotion: reducesMotion, screens: displays)
    let start = rig.panelFrame(.left)
    rig.controller.show(inVisible: displays[0].visible, makeKey: false)
    #expect(await PanelHarness.waitUntil { Self.near(rig.controller.frame, start) })
    #expect(await PanelHarness.waitUntil { rig.controller.panel.alphaValue == 1 })
    let moves = rig.moves
    let target = PanelController.frame(in: displays[1].visible, edge: .left)
    rig.controller.show(inVisible: displays[1].visible, makeKey: true)
    let moved = await Self.panel(rig, settlesAt: target)
    #expect(rig.key.made == 1)
    #expect(rig.controller.isKey)
    #expect(
      moved.allSatisfy { Self.near($0.frame, start) || Self.near($0.frame, target) },
      "the panel crossed: \(moved.map(\.frame))")
    #expect(Self.near(moved.last?.frame, target))
    #expect(moved.last?.alpha == 1)
    #expect(moved.contains { $0.alpha < 1 })
    #expect(rig.controller.restingFrame == target)
    #expect(rig.moves == moves + 1)
    rig.controller.hide()
    #expect(await PanelHarness.waitUntil { !rig.controller.isVisible })
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
  func thePreviewFollowsThePanelToTheOtherDisplayWithoutCrossing(_ reducesMotion: Bool)
    async throws
  {
    let displays = Self.aWideDisplayBesideALowerLaptop()
    let rig = try Rig(edge: .left, reducesMotion: reducesMotion, screens: displays)
    rig.controller.show(inVisible: displays[0].visible, makeKey: false)
    #expect(await PanelHarness.waitUntil { Self.near(rig.controller.frame, rig.panelFrame(.left)) })
    rig.fixture.model.select(rig.shot.file.lastPathComponent, extend: false)
    rig.fixture.model.perform(.preview)
    let start = try rig.previewFrame(.left)
    #expect(
      await PanelHarness.waitUntil { Self.near(rig.preview.frame, start) && rig.preview.alpha == 1 }
    )
    let panel = PanelController.frame(in: displays[1].visible, edge: .left)
    let target = try PreviewPlacementTests.expected(
      for: panel, edge: .left, in: displays[1].visible, fixture: rig.fixture)
    rig.controller.show(inVisible: displays[1].visible, makeKey: true)
    let moved = await Self.samples(
      { (rig.preview.frame, rig.preview.alpha) },
      until: { Self.near(rig.preview.frame, target) && rig.preview.alpha == 1 })
    #expect(
      moved.allSatisfy { Self.near($0.frame, start) || Self.near($0.frame, target) },
      "the preview crossed: \(moved.map(\.frame))")
    #expect(Self.near(moved.last?.frame, target))
    #expect(moved.last?.alpha == 1)
    await rig.finish()
  }
}

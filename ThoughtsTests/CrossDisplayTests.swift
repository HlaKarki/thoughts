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

  static func hlasDisplays(builtInFirst: Bool = false) -> [ScreenFrames] {
    let union = NSScreen.screens.map(\.frame).reduce(CGRect.null) { $0.union($1) }
    let shift = union.maxX + 4000
    let both: [ScreenFrames] = [PanelPlacementTests.external, PanelPlacementTests.builtIn].map {
      ($0.frame.offsetBy(dx: shift, dy: 0), $0.visible.offsetBy(dx: shift, dy: 0))
    }
    return builtInFirst ? both.reversed() : both
  }

  static func samples(_ window: @escaping () -> Sample, for duration: Duration) async -> [Sample] {
    var samples: [Sample] = []
    let end = ContinuousClock.now + duration
    while ContinuousClock.now < end {
      samples.append(window())
      try? await Task.sleep(for: .milliseconds(10))
    }
    samples.append(window())
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

  static func panel(_ rig: Rig) async -> [Sample] {
    await samples(
      { (rig.controller.frame, rig.controller.panel.alphaValue) }, for: .milliseconds(350))
  }

  @Test(arguments: [false, true], [PanelEdge.right, .left])
  func onHlasDisplaysThePanelFadesInPlaceAtTheSharedEdgeAndSlidesAtAnOuterEdge(
    _ onBuiltIn: Bool, _ edge: PanelEdge
  ) async throws {
    let rig = try Rig(
      edge: edge, reducesMotion: false, screens: Self.hlasDisplays(builtInFirst: onBuiltIn))
    let fades = onBuiltIn == (edge == .left)
    let target = rig.panelFrame(edge)
    let gone = PanelController.offscreenFrame(from: target, edge: edge)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    let shown = await Self.panel(rig)
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
    let hidden = await Self.panel(rig)
    #expect(!rig.controller.isVisible)
    #expect(hidden.contains { $0.alpha < 1 })
    if fades {
      #expect(Self.still(hidden, at: target), "the panel moved: \(hidden.map(\.frame))")
    } else {
      #expect(Self.near(hidden.last?.frame, gone))
    }
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test(arguments: [false, true], [PanelEdge.right, .left])
  func withReduceMotionThePanelFadesAtEveryEdgeOfHlasDisplays(
    _ onBuiltIn: Bool, _ edge: PanelEdge
  ) async throws {
    let rig = try Rig(
      edge: edge, reducesMotion: true, screens: Self.hlasDisplays(builtInFirst: onBuiltIn))
    let target = rig.panelFrame(edge)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    let shown = await Self.panel(rig)
    #expect(Self.still(shown, at: target))
    #expect(shown.last?.alpha == 1)
    rig.controller.hide()
    let hidden = await Self.panel(rig)
    #expect(Self.still(hidden, at: target))
    #expect(!rig.controller.isVisible)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }
}

import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized, .throwaway)
struct LiveEdgeTests {
  @MainActor
  final class Displays {
    var list: [ScreenFrames]

    init(_ list: [ScreenFrames]) {
      self.list = list
    }

    func visibleFrame(containing point: CGPoint, or fallback: CGRect) -> CGRect {
      list.first { $0.frame.contains(point) }?.visible ?? fallback
    }
  }

  @MainActor
  final class FakeKey {
    weak var window: NSWindow?
    private(set) var made = 0

    var seam: WindowKey {
      WindowKey(
        isKey: { [unowned self] in window === $0 },
        makeKey: { [unowned self] in
          made += 1
          window = $0
          $0.orderFrontRegardless()
        })
    }
  }

  @MainActor
  final class Rig {
    let fixture: ListFixture
    let preferences: Preferences
    let defaults: UserDefaults
    let screen: (frame: CGRect, visible: CGRect)
    let displays: Displays
    let key = FakeKey()
    let controller: PanelController
    let preview: PreviewWindowController
    let chip: EdgeChipPanel
    let shot: Thought
    private(set) var willShow = 0
    private(set) var willHide = 0
    private(set) var moves = 0

    init(edge: PanelEdge, reducesMotion: Bool = false, screens: [ScreenFrames]? = nil) throws {
      fixture = try ListFixture()
      shot = try fixture.addScreenshot(
        note: "Rename fetchUser before the PR", daysAgo: 0.3,
        source: Source(app: "Editor", bundleID: "com.example.editor", window: "users.ts"))
      try fixture.reload()
      let defaults = try Throwaway.defaults()
      self.defaults = defaults
      let preferences = Preferences(defaults: defaults)
      preferences.edge = edge
      self.preferences = preferences
      let screen =
        screens?.first ?? PreviewPlacementTests.offscreen(CGSize(width: 1728, height: 1117))
      self.screen = screen
      let displays = Displays(screens ?? [screen])
      self.displays = displays
      let hosting = NSHostingView(
        rootView: PanelRootView(preferences: preferences, list: fixture.model, input: fixture.input)
      )
      hosting.sizingOptions = []
      let controller = PanelController(
        content: hosting, preferences: preferences, screens: { displays.list }, key: key.seam,
        reducesMotion: { reducesMotion })
      self.controller = controller
      preview = PreviewWindowController(
        list: fixture.model,
        anchor: {
          controller.isShown ? (controller.restingFrame ?? controller.frame, controller.edge) : nil
        },
        screens: { displays.list }, reducesMotion: { reducesMotion })
      chip = EdgeChipPanel(
        edge: { controller.edge },
        shownPanelFrame: { controller.isShown ? controller.restingFrame : nil },
        plannedPanelFrame: { controller.frame(onVisible: $0) },
        visibleFrame: { displays.visibleFrame(containing: $0, or: screen.visible) },
        screens: { displays.list }, orderFront: { _ in }, reducesMotion: { reducesMotion })
      fixture.model.onPreviewChange = { [preview] in preview.update(showing: $0) }
      controller.onWillShow = { [unowned self] in willShow += 1 }
      controller.onWillHide = { [unowned self] in willHide += 1 }
      controller.onMove = { [preview, chip] in
        self.moves += 1
        preview.reposition()
        chip.reposition()
      }
    }

    func panelFrame(_ edge: PanelEdge) -> CGRect {
      PanelController.frame(in: screen.visible, edge: edge)
    }

    func previewFrame(_ edge: PanelEdge) throws -> CGRect {
      try PreviewPlacementTests.expected(
        for: panelFrame(edge), edge: edge, in: screen.visible, fixture: fixture)
    }

    func chipFrames(_ edge: PanelEdge) -> (chip: CGRect, window: CGRect) {
      EdgeChipPanel.frames(
        size: ChipSurface<EmptyView>.size, visible: screen.visible, edge: edge)
    }

    func showEverything() async throws {
      controller.show(inVisible: screen.visible, makeKey: false)
      let start = preferences.edge
      #expect(controller.frame == panelFrame(start))
      fixture.model.select(shot.file.lastPathComponent, extend: false)
      fixture.model.perform(.preview)
      #expect(fixture.model.isPreviewing)
      chip.show(HintChipView(kind: .nothingToSave))
      let preview = preview
      let chip = chip
      let previewTarget = try previewFrame(start)
      let chipTarget = chipFrames(start).window
      #expect(preview.alpha == 1)
      #expect(preview.frame == previewTarget)
      #expect(
        await PanelHarness.waitUntil {
          chip.windowAlpha == 1 && chip.windowFrame == chipTarget
        }, "the chip never settled at \(start)")
    }

    func finish() async {
      controller.hide()
      chip.hide()
      fixture.model.perform(.preview)
      #expect(!preview.isVisible)
      try? await Task.sleep(for: .milliseconds(300))
      #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
    }
  }

  func settled(_ rig: Rig, at edge: PanelEdge) async throws {
    let panel = rig.panelFrame(edge)
    let preview = try rig.previewFrame(edge)
    let chip = rig.chipFrames(edge)
    #expect(
      await PanelHarness.waitUntil {
        rig.controller.frame == panel && rig.preview.frame == preview
          && rig.chip.windowFrame == chip.window
      },
      "panel \(rig.controller.frame), preview \(rig.preview.frame) and chip \(rig.chip.windowFrame) never reached \(edge)"
    )
    #expect(rig.controller.restingFrame == panel)
    #expect(rig.chip.shownFrame == chip.chip)
    #expect(rig.preview.alpha == 1)
    #expect(rig.chip.windowAlpha == 1)
    #expect(!rig.chip.windowFrame.intersects(panel))
    #expect(!rig.preview.frame.intersects(panel))
  }

  @Test(arguments: [PanelEdge.right, .left])
  func aShownPanelMovesToTheOtherEdgeWithItsPreviewAndChip(_ start: PanelEdge) async throws {
    let rig = try Rig(edge: start)
    try await rig.showEverything()
    rig.fixture.input.text = "draft thought"
    rig.fixture.model.focus = .list
    let selection = rig.fixture.model.selection
    let other: PanelEdge = start == .right ? .left : .right
    rig.preferences.edge = other
    try await settled(rig, at: other)
    #expect(rig.controller.isShown)
    #expect(rig.willShow == 1)
    #expect(rig.willHide == 0)
    #expect(rig.moves == 1)
    #expect(rig.fixture.model.selection == selection)
    #expect(rig.fixture.model.isPreviewing)
    #expect(rig.fixture.model.focus == .list)
    #expect(rig.fixture.input.text == "draft thought")
    await rig.finish()
  }

  @Test(arguments: [
    [PanelEdge.left, .right, .left], [.left, .right], [.left, .right, .left, .right, .left],
  ])
  func quickChangesEndAtTheLastEdgePicked(_ picks: [PanelEdge]) async throws {
    let rig = try Rig(edge: .right)
    try await rig.showEverything()
    for pick in picks { rig.preferences.edge = pick }
    let last = try #require(picks.last)
    try await settled(rig, at: last)
    try? await Task.sleep(for: .milliseconds(400))
    try await settled(rig, at: last)
    #expect(rig.willShow == 1)
    #expect(rig.willHide == 0)
    await rig.finish()
  }

  @Test func changesSeparatedByTheAnimationStillEndAtTheLastEdge() async throws {
    let rig = try Rig(edge: .right)
    try await rig.showEverything()
    for pick in [PanelEdge.left, .right, .left, .right, .left] {
      rig.preferences.edge = pick
      try? await Task.sleep(for: .milliseconds(60))
    }
    try await settled(rig, at: .left)
    try? await Task.sleep(for: .milliseconds(400))
    try await settled(rig, at: .left)
    #expect(rig.willShow == 1)
    await rig.finish()
  }

  @Test func aHiddenPanelStaysHiddenAndShowsAtTheNewEdgeNextTime() async throws {
    let rig = try Rig(edge: .right)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    #expect(rig.controller.frame == rig.panelFrame(.right))
    rig.controller.hide()
    #expect(!rig.controller.isShown)
    rig.preferences.edge = .left
    try? await Task.sleep(for: .milliseconds(400))
    #expect(!rig.controller.isShown)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    #expect(rig.controller.frame == rig.panelFrame(.left))
    #expect(rig.controller.restingFrame == rig.panelFrame(.left))
    rig.controller.hide()
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test(arguments: [PanelEdge.right, .left])
  func aChipShownWhileThePanelIsHiddenFollowsTheEdge(_ start: PanelEdge) async throws {
    let rig = try Rig(edge: start)
    let other: PanelEdge = start == .right ? .left : .right
    rig.chip.show(HintChipView(kind: .nothingToSave))
    #expect(
      await PanelHarness.waitUntil {
        rig.chip.windowAlpha == 1 && rig.chip.windowFrame == rig.chipFrames(start).window
      }, "the chip never settled at \(start)")
    #expect(!rig.controller.isShown)
    rig.preferences.edge = other
    let target = rig.chipFrames(other)
    #expect(
      await PanelHarness.waitUntil {
        rig.chip.windowFrame == target.window && rig.chip.windowAlpha == 1
      }, "the chip stayed at \(rig.chip.windowFrame)")
    #expect(rig.chip.shownFrame == target.chip)
    #expect(!rig.controller.isShown)
    rig.chip.hide()
    try? await Task.sleep(for: .milliseconds(400))
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test(arguments: [0, 60])
  func aHideFollowedQuicklyByAShowLeavesEveryWindowFullyVisible(_ gap: Int) async throws {
    let rig = try Rig(edge: .right)
    try await rig.showEverything()
    let thought = try #require(rig.fixture.model.previewThought)
    rig.controller.hide()
    rig.chip.hide()
    rig.preview.hide()
    if gap > 0 { try? await Task.sleep(for: .milliseconds(gap)) }
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    rig.chip.show(HintChipView(kind: .nothingToSave))
    rig.preview.update(showing: thought)
    let alphas = { [rig.controller.panel.alphaValue, rig.chip.windowAlpha, rig.preview.alpha] }
    #expect(
      await PanelHarness.waitUntil { alphas() == [1, 1, 1] },
      "panel, chip and preview alphas \(alphas())")
    var dips: [[CGFloat]] = []
    let end = ContinuousClock.now + .milliseconds(300)
    while ContinuousClock.now < end {
      try? await Task.sleep(for: .milliseconds(10))
      if alphas() != [1, 1, 1] { dips.append(alphas()) }
    }
    #expect(dips.isEmpty, "a window faded out again: \(dips)")
    #expect(rig.controller.isShown)
    #expect(rig.chip.isShown)
    #expect(rig.preview.isVisible)
    await rig.finish()
  }

  @Test(arguments: [false, true])
  func thePanelAppearsAndDisappearsAtOnceAtTheNewEdge(_ reducesMotion: Bool) async throws {
    let rig = try Rig(edge: .right, reducesMotion: reducesMotion)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    #expect(rig.controller.frame == rig.panelFrame(.right))
    rig.preferences.edge = .left
    #expect(await PanelHarness.waitUntil { rig.controller.frame == rig.panelFrame(.left) })
    rig.controller.hide()
    #expect(!rig.controller.isVisible)
    #expect(rig.controller.frame == rig.panelFrame(.left))
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    #expect(rig.controller.frame == rig.panelFrame(.left))
    #expect(rig.controller.panel.alphaValue == 1)
    rig.controller.hide()
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func withReduceMotionAnEdgeChangeRightAfterAShowEndsAtTheNewEdge() async throws {
    let rig = try Rig(edge: .right, reducesMotion: true)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    rig.preferences.edge = .left
    #expect(
      await PanelHarness.waitUntil { rig.controller.frame == rig.panelFrame(.left) },
      "the panel ended at \(rig.controller.frame)")
    #expect(rig.controller.restingFrame == rig.panelFrame(.left))
    rig.controller.hide()
    #expect(!rig.controller.isVisible)
  }

  @Test func aHideStartedWhileHidingDoesNothing() async throws {
    let rig = try Rig(edge: .right)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    let counted = rig.controller.onWillHide
    rig.controller.onWillHide = { [unowned rig] in
      counted?()
      rig.controller.hide()
      NotificationCenter.default.post(
        name: NSWindow.didResignKeyNotification, object: rig.controller.panel)
    }
    rig.controller.hide()
    try? await Task.sleep(for: .milliseconds(100))
    #expect(rig.willHide == 1)
    #expect(!rig.controller.isVisible)
  }

  @Test(arguments: [PanelEdge.right, .left])
  func aSummonOnTheSameDisplayAfterItsVisibleFrameShrinksStillSlides(_ edge: PanelEdge)
    async throws
  {
    let rig = try Rig(edge: edge, reducesMotion: false)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    let full = rig.screen.visible
    let narrowed = CGRect(
      x: edge == .right ? full.minX : full.minX + 500, y: full.minY, width: full.width - 500,
      height: full.height)
    rig.displays.list = [(rig.screen.frame, narrowed)]
    let target = PanelController.frame(in: narrowed, edge: edge)
    #expect(target != rig.controller.frame)
    rig.controller.show(inVisible: narrowed, makeKey: true)
    #expect(rig.controller.restingFrame == target)
    #expect(rig.controller.frame != target)
    #expect(rig.controller.panel.alphaValue == 1)
    #expect(await PanelHarness.waitUntil { rig.controller.frame == target })
    rig.controller.hide()
  }
}

import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized)
struct PreviewPlacementTests {
  static let menuBar: CGFloat = 37

  static func offscreen(_ size: CGSize, dock: CGFloat = 0, shift: CGFloat = 0)
    -> (frame: CGRect, visible: CGRect)
  {
    let union = NSScreen.screens.map(\.frame).reduce(CGRect.null) { $0.union($1) }
    let frame = CGRect(
      x: union.maxX + 4000 + shift, y: union.minY, width: size.width, height: size.height)
    let visible = CGRect(
      x: frame.minX, y: frame.minY + dock, width: frame.width,
      height: frame.height - menuBar - dock)
    return (frame, visible)
  }

  static func showPreview(
    of thought: Thought, in fixture: ListFixture, anchor: CGRect, edge: PanelEdge,
    screens: [(frame: CGRect, visible: CGRect)]
  ) async throws -> PreviewWindowController {
    let preview = PreviewWindowController(
      list: fixture.model, anchor: { (anchor, edge) }, screens: { screens })
    fixture.model.onPreviewChange = { preview.update(showing: $0) }
    fixture.model.select(thought.file.lastPathComponent, extend: false)
    fixture.model.perform(.preview)
    #expect(fixture.model.isPreviewing)
    #expect(await PanelHarness.waitUntil { preview.alpha == 1 }, "the preview never faded in")
    return preview
  }

  static func expected(
    for anchor: CGRect, edge: PanelEdge, in visible: CGRect, fixture: ListFixture
  ) throws -> CGRect {
    let thought = try #require(fixture.model.previewThought)
    return PreviewWindowController.placement(beside: anchor, edge: edge, in: visible) {
      PreviewWindowController.height(of: thought, layout: $0)
    }.frame
  }

  static func close(_ preview: PreviewWindowController, _ fixture: ListFixture) async throws {
    fixture.model.perform(.preview)
    #expect(await PanelHarness.waitUntil { !preview.isVisible }, "the preview never hid")
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func theReportedImagePreviewSitsBesideThePanelInsideTheScreen() async throws {
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    let shot = try fixture.addScreenshot(
      note: "", daysAgo: 0.3,
      source: Source(app: "Safari", bundleID: "com.apple.Safari", title: "Release notes"),
      pixels: (3910, 2710))
    try fixture.reload()
    let screen = Self.offscreen(CGSize(width: 1728, height: 1117))
    let anchor = PanelController.frame(in: screen.visible, edge: .right)
    let preview = try await Self.showPreview(
      of: shot, in: fixture, anchor: anchor, edge: .right, screens: [screen])
    let frame = preview.frame
    #expect(screen.visible.contains(frame), "the preview at \(frame) left \(screen.visible)")
    #expect(!frame.intersects(anchor), "the preview at \(frame) covers the panel at \(anchor)")
    #expect(frame.maxX == anchor.minX - PreviewWindowController.gap)
    #expect(frame.width == PreviewCardLayout.fullWidth)
    #expect(frame.midY == anchor.midY)
    #expect(
      frame
        == (try Self.expected(for: anchor, edge: .right, in: screen.visible, fixture: fixture)))
    let image = try #require(fixture.model.previewThought?.imageFileURL)
    try #require(
      await PanelHarness.waitUntil { preview.loadedImage == image }, "the image never loaded")
    let moved = await PanelHarness.waitUntil(within: .milliseconds(500)) { preview.frame != frame }
    #expect(!moved, "the preview moved to \(preview.frame) after its image loaded")
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
    try await Self.close(preview, fixture)
  }

  @Test(arguments: [PanelEdge.right, .left])
  func aNarrowScreenGetsANarrowerPreviewWindowAtItsComputedFrame(_ edge: PanelEdge) async throws {
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    let shot = try fixture.addScreenshot(
      note: "Rename fetchUser before the PR", daysAgo: 0.3,
      source: Source(app: "Editor", bundleID: "com.example.editor", window: "users.ts in api"))
    try fixture.reload()
    let screen = Self.offscreen(CGSize(width: 900, height: 700))
    let anchor = PanelController.frame(in: screen.visible, edge: edge)
    let preview = try await Self.showPreview(
      of: shot, in: fixture, anchor: anchor, edge: edge, screens: [screen])
    let frame = preview.frame
    #expect(
      frame == (try Self.expected(for: anchor, edge: edge, in: screen.visible, fixture: fixture)))
    #expect(frame.width < PreviewCardLayout.fullWidth)
    #expect(frame.width >= PreviewCardLayout.minimumWidth)
    #expect(screen.visible.contains(frame), "the preview at \(frame) left \(screen.visible)")
    #expect(!frame.intersects(anchor), "the preview at \(frame) covers the panel at \(anchor)")
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
    try await Self.close(preview, fixture)
  }

  @Test func thePreviewWindowFollowsItsThoughtWhenItGainsADoneLine() async throws {
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    let shot = try fixture.addScreenshot(note: "", daysAgo: 0.3)
    try fixture.reload()
    let screen = Self.offscreen(CGSize(width: 1728, height: 1117))
    let anchor = PanelController.frame(in: screen.visible, edge: .right)
    let preview = try await Self.showPreview(
      of: shot, in: fixture, anchor: anchor, edge: .right, screens: [screen])
    let before = preview.frame
    _ = try fixture.store.setDone(true, for: shot.id, at: ListFixture.now)
    try fixture.reload()
    #expect(fixture.model.previewThought?.done != nil)
    let target = try Self.expected(for: anchor, edge: .right, in: screen.visible, fixture: fixture)
    #expect(await PanelHarness.waitUntil { preview.frame == target }, "the preview never grew")
    let after = preview.frame
    #expect(after.height > before.height)
    #expect(
      after == (try Self.expected(for: anchor, edge: .right, in: screen.visible, fixture: fixture)))
    #expect(screen.visible.contains(after))
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
    try await Self.close(preview, fixture)
  }

  @Test func thePreviewEndsWhenTheListDropsItsThoughtWithoutASelectionChange() async throws {
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    let shot = try fixture.addScreenshot(note: "", daysAgo: 0.3)
    try fixture.reload()
    let screen = Self.offscreen(CGSize(width: 1728, height: 1117))
    let anchor = PanelController.frame(in: screen.visible, edge: .right)
    let preview = try await Self.showPreview(
      of: shot, in: fixture, anchor: anchor, edge: .right, screens: [screen])
    let name = shot.file.lastPathComponent
    fixture.model.holdRemoval(of: [name])
    #expect(fixture.model.selection == [name])
    #expect(fixture.model.previewThought == nil)
    #expect(await PanelHarness.waitUntil { !preview.isVisible }, "the preview stayed up")
    #expect(!fixture.model.isPreviewing)
    fixture.model.releaseRemoval(of: [name])
    fixture.model.perform(.preview)
    #expect(fixture.model.isPreviewing)
    #expect(await PanelHarness.waitUntil { preview.alpha == 1 }, "the preview never came back")
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
    try await Self.close(preview, fixture)
  }

  @Test func aPanelOnNoScreenStillGetsItsPreviewInsideTheNearestScreen() async throws {
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    let shot = try fixture.addScreenshot(note: "", daysAgo: 0.3)
    try fixture.reload()
    let near = Self.offscreen(CGSize(width: 1728, height: 1117))
    let far = Self.offscreen(CGSize(width: 1440, height: 900), shift: 6000)
    let resting = PanelController.frame(in: near.visible, edge: .right)
    let anchor = resting.offsetBy(dx: PanelController.width + 40, dy: 0)
    #expect(!near.frame.intersects(anchor))
    #expect(!far.frame.intersects(anchor))
    let preview = try await Self.showPreview(
      of: shot, in: fixture, anchor: anchor, edge: .right, screens: [far, near])
    let frame = preview.frame
    #expect(frame.width > 0)
    #expect(near.visible.contains(frame), "the preview at \(frame) left \(near.visible)")
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
    try await Self.close(preview, fixture)
  }

  static func height(_ layout: PreviewCardLayout) -> CGFloat {
    layout.mediaHeight + 140
  }

  static func placed(_ panel: CGRect, _ edge: PanelEdge, _ visible: CGRect) -> CGRect {
    PreviewWindowController.placement(beside: panel, edge: edge, in: visible, height: height)
      .frame
  }

  nonisolated static let builtInSizes = [
    CGSize(width: 1312, height: 848), CGSize(width: 1496, height: 967),
    CGSize(width: 1728, height: 1117), CGSize(width: 2056, height: 1329),
    CGSize(width: 3456, height: 2234),
  ]

  @Test(arguments: PreviewPlacementTests.builtInSizes, [PanelEdge.right, .left])
  func everySizeOfTheBuiltInDisplayPutsThePreviewBesideThePanel(
    _ size: CGSize, _ edge: PanelEdge
  ) {
    for dock: CGFloat in [0, 74] {
      let visible = CGRect(x: 0, y: dock, width: size.width, height: size.height - 37 - dock)
      let panel = PanelController.frame(in: visible, edge: edge)
      let frame = Self.placed(panel, edge, visible)
      #expect(visible.contains(frame), "\(size) dock \(dock): \(frame) left \(visible)")
      #expect(!frame.intersects(panel), "\(size) dock \(dock): \(frame) covers \(panel)")
      #expect(frame.width == PreviewCardLayout.fullWidth)
      #expect(frame.height == PreviewCardLayout.full.mediaHeight + 140)
      #expect(frame.midY == panel.midY)
      switch edge {
      case .right: #expect(frame.maxX == panel.minX - PreviewWindowController.gap)
      case .left: #expect(frame.minX == panel.maxX + PreviewWindowController.gap)
      }
    }
  }

  @Test func aSideWithLessRoomThanThePreviewGetsANarrowerPreviewWithASmallerImage() {
    let visible = CGRect(x: 0, y: 0, width: 888, height: 900)
    let panel = PanelController.frame(in: visible, edge: .right)
    let placed = PreviewWindowController.placement(
      beside: panel, edge: .right, in: visible, height: Self.height)
    #expect(placed.frame.minX == visible.minX)
    #expect(placed.frame.maxX == panel.minX - PreviewWindowController.gap)
    #expect(placed.frame.width == 500)
    #expect(placed.layout.width == 500)
    #expect(placed.layout.mediaWidth == 476)
    #expect(placed.layout.mediaHeight == (372.0 * 476 / 596).rounded())
    #expect(placed.frame.height == placed.layout.mediaHeight + 140)
  }

  @Test(arguments: [PanelEdge.right, .left])
  func withoutTheMinimumOnEitherSideThePreviewSitsOverTheList(_ edge: PanelEdge) {
    let visible = CGRect(x: 0, y: 0, width: 700, height: 900)
    let panel = PanelController.frame(in: visible, edge: edge)
    let frame = Self.placed(panel, edge, visible)
    #expect(frame.width == PreviewCardLayout.minimumWidth)
    #expect(frame.minX == panel.minX + PreviewWindowController.gap)
    #expect(frame.maxX == panel.maxX - PreviewWindowController.gap)
    #expect(frame.midY == panel.midY)
    #expect(visible.contains(frame))
  }

  @Test func thePreviewTakesTheOtherSideWhenOnlyThatSideHasRoom() {
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let panel = CGRect(x: 40, y: 44, width: PanelController.width, height: 812)
    let frame = Self.placed(panel, .right, visible)
    #expect(frame.minX == panel.maxX + PreviewWindowController.gap)
    #expect(frame.width == PreviewCardLayout.fullWidth)
    #expect(visible.contains(frame))
  }

  @Test func aShortPanelShrinksThePreviewImageSoThePreviewIsNoTallerThanThePanel() {
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 432)
    let panel = PanelController.frame(in: visible, edge: .right)
    #expect(panel.height == 400)
    let placed = PreviewWindowController.placement(
      beside: panel, edge: .right, in: visible, height: Self.height)
    #expect(placed.frame.height == 400)
    #expect(placed.layout.mediaHeight == 260)
    #expect(placed.frame.width == PreviewCardLayout.fullWidth)
    #expect(visible.contains(placed.frame))
  }

  @Test func aPanelOnNoScreenUsesTheNearestScreenAndOtherwiseTheOneItSitsOnMost() {
    let left = (
      frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
      visible: CGRect(x: 0, y: 0, width: 1728, height: 1080)
    )
    let right = (
      frame: CGRect(x: 1728, y: 0, width: 2560, height: 1440),
      visible: CGRect(x: 1728, y: 0, width: 2560, height: 1403)
    )
    let screens = [left, right]
    let beyond = CGRect(x: 4400, y: 100, width: 360, height: 812)
    #expect(PreviewWindowController.visibleFrame(for: beyond, among: screens) == right.visible)
    let below = CGRect(x: 200, y: -2000, width: 360, height: 812)
    #expect(PreviewWindowController.visibleFrame(for: below, among: screens) == left.visible)
    let straddling = CGRect(x: 1500, y: 100, width: 360, height: 812)
    #expect(PreviewWindowController.visibleFrame(for: straddling, among: screens) == left.visible)
    let mostlyRight = CGRect(x: 1600, y: 100, width: 360, height: 812)
    #expect(PreviewWindowController.visibleFrame(for: mostlyRight, among: screens) == right.visible)
    #expect(PreviewWindowController.visibleFrame(for: beyond, among: []) == nil)
    let frame = Self.placed(beyond, .right, right.visible)
    #expect(right.visible.contains(frame))
    #expect(!frame.intersects(beyond))
  }
}

import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
@Suite(.serialized)
struct NeighborPlacementTests {
  static let nowhere = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)

  static func panels(in visible: CGRect, edge: PanelEdge) -> [(String, CGRect)] {
    let size = PanelController.frame(in: visible, edge: edge).size
    let toward: CGFloat = edge == .right ? 1 : -1
    let center = visible.midX + toward * 20
    let xs: [(String, CGFloat)] = [
      ("at the edge", PanelController.frame(in: visible, edge: edge).minX),
      ("in the middle", center - size.width / 2),
      (
        "100 pt from the edge",
        edge == .right ? visible.maxX - 100 - size.width : visible.minX + 100
      ),
    ]
    let ys: [(String, CGFloat)] = [
      ("top", visible.maxY - 16 - size.height),
      ("middle", visible.midY - size.height / 2),
      ("bottom", visible.minY + 16),
      ("60 pt up", visible.minY + 60),
    ]
    return xs.flatMap { x in
      ys.map { y in ("\(x.0), \(y.0)", CGRect(origin: CGPoint(x: x.1, y: y.1), size: size)) }
    }
  }

  static func label(_ size: CGSize, _ dock: CGFloat, _ edge: PanelEdge, _ spot: String) -> String {
    "\(Int(size.width))x\(Int(size.height)) dock \(Int(dock)) \(edge), panel \(spot)"
  }

  @Test(arguments: ChipPlacementTests.sizes, [PanelEdge.right, .left])
  func everyChipLiesInsideTheScreenAndOffAPanelAnywhereOnIt(_ size: CGSize, _ edge: PanelEdge) {
    for dock: CGFloat in [0, 50, 74] {
      let visible = ChipPlacementTests.visible(size, dock: dock)
      for (spot, panel) in Self.panels(in: visible, edge: edge) {
        let label = Self.label(size, dock, edge, spot)
        #expect(visible.contains(panel), "\(label): the spot \(panel) leaves \(visible)")
        let (chip, window) = EdgeChipPanel.frames(
          size: ChipSurface<EmptyView>.size, visible: visible, edge: edge, panel: panel)
        #expect(visible.contains(window), "\(label): \(window) leaves \(visible)")
        #expect(!window.intersects(panel), "\(label): \(window) covers \(panel)")
        #expect(window.contains(chip), "\(label): \(window) cuts \(chip)")
        let gap = EdgeChipPanel.panelGap - 1
        #expect(!chip.insetBy(dx: -gap, dy: -gap).intersects(panel), "\(label): \(chip) too near")
        #expect(chip.minY == visible.minY + EdgeChipPanel.bottomInset, "\(label): \(chip)")
      }
    }
  }

  @Test(arguments: [PanelEdge.right, .left])
  func aChipStaysAtTheScreenEdgeUnlessThePanelIsInTheWay(_ edge: PanelEdge) {
    let visible = ChipPlacementTests.visible(CGSize(width: 1728, height: 1117), dock: 0)
    let size = ChipSurface<EmptyView>.size
    let atEdge = EdgeChipPanel.frames(size: size, visible: visible, edge: edge, panel: Self.nowhere)
      .chip
    for (spot, panel) in Self.panels(in: visible, edge: edge) {
      let chip = EdgeChipPanel.frames(size: size, visible: visible, edge: edge, panel: panel).chip
      let blocked = atEdge.insetBy(dx: -EdgeChipPanel.panelGap, dy: -EdgeChipPanel.panelGap)
        .intersects(panel)
      if blocked {
        switch edge {
        case .right: #expect(chip.maxX == panel.minX - EdgeChipPanel.panelGap, "\(spot): \(chip)")
        case .left: #expect(chip.minX == panel.maxX + EdgeChipPanel.panelGap, "\(spot): \(chip)")
        }
      } else {
        #expect(chip == atEdge, "\(spot): \(chip)")
      }
    }
  }

  @Test func aShownChipKeepsOffThePanelWhereItIsAndNotWhereItStartsOut() async throws {
    let visible = ChipPlacementTests.visible(CGSize(width: 1728, height: 1117), dock: 0)
    let panel = CGRect(x: visible.maxX - 476, y: visible.minY + 16, width: 360, height: 640)
    let chip = EdgeChipPanel(
      edge: { .right }, shownPanelFrame: { panel }, visibleFrame: { _ in visible },
      orderFront: { _ in })
    chip.show(HintChipView(kind: .nothingToSave))
    #expect(await PanelHarness.waitUntil { chip.windowAlpha == 1 }, "the chip never showed")
    #expect(!chip.windowFrame.intersects(panel), "\(chip.windowFrame) covers \(panel)")
    #expect(visible.contains(chip.windowFrame))
    chip.hide()
    #expect(await PanelHarness.waitUntil { chip.windowAlpha == 0 }, "the chip never faded out")
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test(arguments: PreviewPlacementTests.builtInSizes, [PanelEdge.right, .left])
  func thePreviewSitsTwelvePointsBesideAPanelAnywhereOnTheScreen(
    _ size: CGSize, _ edge: PanelEdge
  ) {
    for dock: CGFloat in [0, 74] {
      let visible = PanelPlacementTests.visible(size, dock: dock)
      for (spot, panel) in Self.panels(in: visible, edge: edge) {
        let label = Self.label(size, dock, edge, spot)
        let frame = PreviewPlacementTests.placed(panel, edge, visible)
        #expect(visible.contains(frame), "\(label): \(frame) leaves \(visible)")
        #expect(!frame.intersects(panel), "\(label): \(frame) covers \(panel)")
        #expect(frame.midY == panel.midY, "\(label): \(frame)")
        #expect(frame.width >= PreviewCardLayout.minimumWidth, "\(label): \(frame)")
        let gap = PreviewWindowController.gap
        let onLeft = frame.maxX == panel.minX - gap
        let onRight = frame.minX == panel.maxX + gap
        #expect(onLeft != onRight, "\(label): \(frame) is not \(gap) pt from \(panel)")
        let leftRoom = panel.minX - gap - visible.minX
        let rightRoom = visible.maxX - panel.maxX - gap
        let inward = edge == .right ? onLeft : onRight
        if !inward {
          let inwardRoom = edge == .right ? leftRoom : rightRoom
          let outwardRoom = edge == .right ? rightRoom : leftRoom
          #expect(
            inwardRoom < PreviewCardLayout.fullWidth && inwardRoom < outwardRoom,
            "\(label): the preview left \(inwardRoom) pt of room for \(outwardRoom)")
        }
      }
    }
  }

  @Test(arguments: PreviewPlacementTests.builtInSizes, [PanelEdge.right, .left])
  func theEdgeDropZoneNeverTouchesAPanelAnywhereOnTheScreen(_ size: CGSize, _ edge: PanelEdge) {
    for dock: CGFloat in [0, 74] {
      let screen = CGRect(origin: .zero, size: size)
      let visible = PanelPlacementTests.visible(size, dock: dock)
      let zone = EdgeDropZone.frame(screen: screen, visible: visible, edge: edge)
      for (spot, panel) in Self.panels(in: visible, edge: edge) {
        #expect(!zone.intersects(panel), "\(Self.label(size, dock, edge, spot)): \(zone)")
      }
    }
  }
}

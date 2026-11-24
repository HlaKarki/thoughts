import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
struct HintChipTests {
  static let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
  static let size = CGSize(width: 300, height: 60)
  static let bottom: CGFloat = 25 + 32

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func hintChip(_ appearance: NSAppearance.Name) throws {
    let canvas = CGSize(
      width: ChipSurface<EmptyView>.size.width + 2 * EdgeChipPanel.shadowMargin,
      height: ChipSurface<EmptyView>.size.height + 2 * EdgeChipPanel.shadowMargin)
    let tone = appearance == .aqua ? "light" : "dark"
    let image = try OfferChipTests.thumbnail()
    let prose = "It fills up after 10, so get on early at Martim Moniz. Bring a book and a coat."
    for (kind, name) in [
      (HintChipView.Kind.nothingToSave, "nothing-to-save"),
      (.saved(SavedPreview(line: prose, thumbnail: nil)), "saved"),
      (
        .saved(SavedPreview(line: "Screenshot 2026-11-23 at 10.05.12", thumbnail: image)),
        "saved-image"
      ),
      (.saved(SavedPreview(line: nil, thumbnail: image)), "saved-image-bare"),
      (.alreadySaved(SavedPreview(line: prose, thumbnail: nil)), "already-saved"),
      (.alreadySaved(SavedPreview(line: "cat photo.png", thumbnail: image)), "already-saved-image"),
      (.failed("The thoughts folder isn't available: Thoughts"), "failed"),
    ] {
      let url = try SnapshotRenderer.render(
        HintChipView(kind: kind).padding(EdgeChipPanel.shadowMargin),
        size: canvas, appearance: appearance, name: "hint-chip-\(name)-\(tone)")
      let image = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
      #expect(image.pixelsWide == Int(canvas.width) * SnapshotRenderer.scale)
      #expect(image.pixelsHigh == Int(canvas.height) * SnapshotRenderer.scale)
      #expect(SnapshotTests.colorCount(of: image) > 1)
    }
  }

  static let tall = CGRect(x: 0, y: 25, width: 2560, height: 1415)

  @Test func chipSitsAtTheEdgeOnATallScreenWhateverTheEdge() {
    let right = EdgeChipPanel.chipFrame(size: Self.size, visible: Self.tall, edge: .right)
    #expect(right == CGRect(x: 2560 - 12 - 300, y: 25 + 32, width: 300, height: 60))
    let left = EdgeChipPanel.chipFrame(size: Self.size, visible: Self.tall, edge: .left)
    #expect(left == CGRect(x: 12, y: 25 + 32, width: 300, height: 60))
    for edge in [PanelEdge.left, .right] {
      let panel = PanelController.frame(in: Self.tall, edge: edge)
      let chip = EdgeChipPanel.chipFrame(size: Self.size, visible: Self.tall, edge: edge)
      #expect(
        chip.insetBy(dx: -EdgeChipPanel.panelGap, dy: -EdgeChipPanel.panelGap).intersects(panel)
          == false)
    }
  }

  @Test func chipSitsBesideThePanelsRestingFrameOnAShortScreen() {
    let rightPanel = PanelController.frame(in: Self.visible, edge: .right)
    let right = EdgeChipPanel.chipFrame(size: Self.size, visible: Self.visible, edge: .right)
    #expect(right.maxX == rightPanel.minX - 12)
    #expect(right.minY == Self.bottom)
    let leftPanel = PanelController.frame(in: Self.visible, edge: .left)
    let left = EdgeChipPanel.chipFrame(size: Self.size, visible: Self.visible, edge: .left)
    #expect(left.minX == leftPanel.maxX + 12)
    #expect(left.minY == Self.bottom)
  }

  @Test func aShownChipKeepsItsFrameWhateverThePanelDoes() {
    for (visible, edge) in [
      (Self.visible, PanelEdge.right), (Self.visible, .left), (Self.tall, .right),
    ] {
      let chip = EdgeChipPanel(edge: { edge }, visibleFrame: { visible }, orderFront: { _ in })
      chip.show(Text("one"))
      let first = chip.shownFrame
      chip.show(Text("two"))
      #expect(first == EdgeChipPanel.chipFrame(size: Self.size, visible: visible, edge: edge))
      #expect(chip.shownFrame == first)
      chip.hide()
      #expect(chip.shownFrame == nil)
    }
  }
}

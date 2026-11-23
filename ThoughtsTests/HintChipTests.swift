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

  @Test func chipSitsInFromTheEdgeAndUpFromTheBottom() {
    let right = EdgeChipPanel.chipFrame(
      size: Self.size, visible: Self.visible, edge: .right, openPanel: nil)
    #expect(right == CGRect(x: 1440 - 12 - 300, y: 25 + 32, width: 300, height: 60))
    let left = EdgeChipPanel.chipFrame(
      size: Self.size, visible: Self.visible, edge: .left, openPanel: nil)
    #expect(left == CGRect(x: 12, y: 25 + 32, width: 300, height: 60))
  }

  @Test func chipMovesBesideTheOpenPanelKeepingItsBottomOffset() {
    let rightPanel = PanelController.frame(in: Self.visible, edge: .right)
    let right = EdgeChipPanel.chipFrame(
      size: Self.size, visible: Self.visible, edge: .right, openPanel: rightPanel)
    #expect(right.maxX == rightPanel.minX - 12)
    #expect(right.minY == Self.bottom)
    let leftPanel = PanelController.frame(in: Self.visible, edge: .left)
    let left = EdgeChipPanel.chipFrame(
      size: Self.size, visible: Self.visible, edge: .left, openPanel: leftPanel)
    #expect(left.minX == leftPanel.maxX + 12)
    #expect(left.minY == Self.bottom)
  }
}

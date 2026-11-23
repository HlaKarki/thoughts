import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct OfferChipTests {
  static func thumbnail() throws -> NSImage {
    let data = try ListFixture.png()
    return try #require(NSImage(data: data))
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func offerChips(_ appearance: NSAppearance.Name) throws {
    let canvas = CGSize(
      width: ChipSurface<EmptyView>.size.width + 2 * EdgeChipPanel.shadowMargin,
      height: ChipSurface<EmptyView>.size.height + 2 * EdgeChipPanel.shadowMargin)
    let tone = appearance == .aqua ? "light" : "dark"
    let image = try Self.thumbnail()
    let cases: [(OfferChipView.Kind, NSImage?, Modifier?, String)] = [
      (.clipboard, image, .shift, "clipboard"),
      (.clipboard, nil, .shift, "clipboard-no-thumbnail"),
      (.file, image, .shift, "file"),
      (.file, nil, .shift, "file-no-thumbnail"),
      (.clipboard, nil, nil, "clipboard-gesture-off"),
    ]
    for (kind, thumbnail, gesture, name) in cases {
      let view = OfferChipView(kind: kind, thumbnail: thumbnail, gesture: gesture)
      let url = try SnapshotRenderer.render(
        view.padding(EdgeChipPanel.shadowMargin), size: canvas, appearance: appearance,
        name: "offer-chip-\(name)-\(tone)")
      let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
      #expect(bitmap.pixelsWide == Int(canvas.width) * SnapshotRenderer.scale)
      #expect(bitmap.pixelsHigh == Int(canvas.height) * SnapshotRenderer.scale)
      #expect(SnapshotTests.colorCount(of: bitmap) > 1)
    }
  }

  @Test func offerChipIsTheSameSizeAsAHintChip() throws {
    let offer = NSHostingView(
      rootView: OfferChipView(kind: .file, thumbnail: nil, gesture: .shift))
    let hint = NSHostingView(rootView: HintChipView(kind: .saved))
    #expect(offer.fittingSize == hint.fittingSize)
    #expect(offer.fittingSize.width >= 300)
  }
}

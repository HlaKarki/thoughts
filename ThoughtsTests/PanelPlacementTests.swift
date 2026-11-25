import AppKit
import Testing

@testable import Thoughts

@MainActor
struct PanelPlacementTests {
  static func visible(_ size: CGSize, dock: CGFloat = 0) -> CGRect {
    CGRect(x: 0, y: dock, width: size.width, height: size.height - 37 - dock)
  }

  @Test(arguments: PreviewPlacementTests.builtInSizes, [PanelEdge.right, .left])
  func theDefaultPanelIs640TallAndCenteredAtItsEdgeOnEveryBuiltInSize(
    _ size: CGSize, _ edge: PanelEdge
  ) {
    for dock: CGFloat in [0, 74] {
      let visible = Self.visible(size, dock: dock)
      let frame = PanelController.frame(in: visible, edge: edge)
      let label = "\(size) dock \(dock) \(edge)"
      #expect(frame.size == CGSize(width: 360, height: 640), "\(label): \(frame)")
      #expect(frame.midY == visible.midY, "\(label): \(frame)")
      #expect(visible.contains(frame), "\(label): \(frame) left \(visible)")
      switch edge {
      case .right: #expect(frame.maxX == visible.maxX - 16, "\(label): \(frame)")
      case .left: #expect(frame.minX == visible.minX + 16, "\(label): \(frame)")
      }
    }
  }

  @Test(arguments: [CGFloat(671), 600, 432])
  func aScreenShorterThan672GivesAPanel32ShorterThanItsVisibleFrame(_ height: CGFloat) {
    let visible = CGRect(x: 0, y: 25, width: 1440, height: height)
    for edge in [PanelEdge.right, .left] {
      let frame = PanelController.frame(in: visible, edge: edge)
      #expect(frame.height == height - 32)
      #expect(frame.minY == visible.minY + 16)
      #expect(frame.maxY == visible.maxY - 16)
      #expect(frame.width == 360)
    }
    let roomy = CGRect(x: 0, y: 25, width: 1440, height: 672)
    #expect(PanelController.frame(in: roomy, edge: .right).height == 640)
  }
}

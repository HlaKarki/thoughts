import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
@Suite(.serialized)
struct ChipPlacementTests {
  static func visible(_ size: CGSize, dock: CGFloat) -> CGRect {
    CGRect(x: 0, y: dock, width: size.width, height: size.height - 37 - dock)
  }

  struct Screen: Sendable, CustomTestStringConvertible {
    let size: CGSize
    let edge: PanelEdge
    let dock: CGFloat
    var testDescription: String {
      "\(Int(size.width))x\(Int(size.height)) \(edge) dock \(Int(dock))"
    }
  }

  nonisolated static let shownCases = [
    Screen(size: CGSize(width: 1728, height: 1117), edge: .right, dock: 0),
    Screen(size: CGSize(width: 1728, height: 1117), edge: .right, dock: 50),
    Screen(size: CGSize(width: 1728, height: 1117), edge: .left, dock: 74),
    Screen(size: CGSize(width: 1312, height: 848), edge: .right, dock: 0),
  ]

  @Test(arguments: ChipPlacementTests.shownCases)
  func aShownChipWindowLiesInsideTheScreenAndOffThePanel(_ screen: Screen) async throws {
    let (size, edge, dock) = (screen.size, screen.edge, screen.dock)
    let visible = Self.visible(size, dock: dock)
    let panel = PanelController.frame(in: visible, edge: edge)
    for onClick in [nil, {}] as [(() -> Void)?] {
      let chip = EdgeChipPanel(
        edge: { edge }, shownPanelFrame: { panel }, visibleFrame: { _ in visible },
        orderFront: { _ in })
      chip.show(HintChipView(kind: .nothingToSave), onClick: onClick)
      try await Task.sleep(for: .milliseconds(350))
      let frame = chip.windowFrame
      let shown = try #require(chip.shownFrame)
      #expect(visible.contains(frame), "\(size) dock \(dock) \(edge): \(frame) left \(visible)")
      #expect(!frame.intersects(panel), "\(size) dock \(dock) \(edge): \(frame) covers \(panel)")
      #expect(frame.contains(shown))
      #expect(shown.size == ChipSurface<EmptyView>.size)
      let computed = EdgeChipPanel.frames(size: shown.size, visible: visible, edge: edge)
      #expect(frame == computed.window)
      #expect(shown == computed.chip)
      chip.hide()
      try await Task.sleep(for: .milliseconds(300))
    }
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  nonisolated static let sizes = [
    CGSize(width: 1312, height: 848), CGSize(width: 1440, height: 900),
    CGSize(width: 1496, height: 967), CGSize(width: 1728, height: 1117),
    CGSize(width: 2056, height: 1329), CGSize(width: 2560, height: 1440),
    CGSize(width: 3456, height: 2234),
  ]

  @Test(arguments: ChipPlacementTests.sizes, [PanelEdge.right, .left])
  func everyChipWindowLiesInsideTheScreenAndOffThePanel(_ size: CGSize, _ edge: PanelEdge) {
    for dock: CGFloat in [0, 50, 74] {
      let visible = Self.visible(size, dock: dock)
      let panel = PanelController.frame(in: visible, edge: edge)
      let (chip, window) = EdgeChipPanel.frames(
        size: ChipSurface<EmptyView>.size, visible: visible, edge: edge)
      let label = "\(size) dock \(dock) \(edge)"
      #expect(visible.contains(window), "\(label): \(window) left \(visible)")
      #expect(!window.intersects(panel), "\(label): \(window) covers \(panel)")
      #expect(window.contains(chip), "\(label): \(window) cuts \(chip)")
      let gap = EdgeChipPanel.panelGap - 1
      #expect(!chip.insetBy(dx: -gap, dy: -gap).intersects(panel), "\(label): \(chip) too near")
      #expect(chip.minY == visible.minY + EdgeChipPanel.bottomInset)
      let padding = EdgeChipPanel.padding(around: chip, in: window)
      #expect(min(padding.top, padding.leading, padding.bottom, padding.trailing) >= 0)
      #expect(padding.bottom == EdgeChipPanel.bottomInset)
      #expect(chip.width + padding.leading + padding.trailing == window.width)
      #expect(chip.height + padding.top + padding.bottom == window.height)
    }
  }

  @Test func thePaddedChipIsExactlyTheSizeOfItsWindowSoSwiftUINeverResizesIt() {
    let visible = Self.visible(CGSize(width: 1728, height: 1117), dock: 50)
    let (chip, window) = EdgeChipPanel.frames(
      size: ChipSurface<EmptyView>.size, visible: visible, edge: .right)
    #expect(window.height < chip.height + 2 * EdgeChipPanel.shadowMargin)
    let padding = EdgeChipPanel.padding(around: chip, in: window)
    for view in [
      AnyView(HintChipView(kind: .nothingToSave).padding(padding)),
      AnyView(
        OfferChipView(kind: .clipboard, thumbnail: nil, keycap: .doubled(.shift)).padding(padding)),
    ] {
      #expect(NSHostingView(rootView: view).fittingSize == window.size)
    }
  }
}

import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
struct SnapshotTests {
  static let panelSize = CGSize(width: PanelController.width, height: PanelController.maxHeight)

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func panelChrome(_ appearance: NSAppearance.Name) async throws {
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let url = try SnapshotRenderer.render(
      PanelRootView(
        preferences: Preferences(defaults: defaults), list: fixture.model, input: fixture.input),
      size: Self.panelSize,
      appearance: appearance,
      name: "panel-empty-\(appearance == .aqua ? "light" : "dark")")
    let image = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
    #expect(image.pixelsWide == Int(Self.panelSize.width) * SnapshotRenderer.scale)
    #expect(image.pixelsHigh == Int(Self.panelSize.height) * SnapshotRenderer.scale)
    #expect(Self.colorCount(of: image) > 1)
    await ListFixture.settle()
  }

  static func colorCount(of image: NSBitmapImageRep) -> Int {
    var colors = Set<UInt32>()
    for y in stride(from: 0, to: image.pixelsHigh, by: 3) {
      for x in stride(from: 0, to: image.pixelsWide, by: 3) {
        guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        let red = UInt32(color.redComponent * 255)
        let green = UInt32(color.greenComponent * 255)
        let blue = UInt32(color.blueComponent * 255)
        colors.insert(red << 16 | green << 8 | blue)
      }
    }
    return colors.count
  }
}

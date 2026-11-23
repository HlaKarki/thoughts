import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct ListSnapshotTests {
  static let panelSize = CGSize(width: 360, height: 812)

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func listStates(_ appearance: NSAppearance.Name) async throws {
    let suffix = appearance == .aqua ? "light" : "dark"
    let empty = try ListFixture()
    defer { withExtendedLifetime(empty) {} }
    try empty.reload()
    let emptyImage = try Self.image(
      of: empty.model, input: empty.input, appearance: appearance, name: "list-empty-\(suffix)")

    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    try fixture.addText("Renew car registration", daysAgo: 4.01, done: true)
    try fixture.addScreenshot(note: "", daysAgo: 4, done: true)
    let noted = try fixture.addScreenshot(note: "Reword the empty state", daysAgo: 3)
    try fixture.addUnreadable(name: "20261121-140200-k3f9.md", daysAgo: 3)
    try fixture.addText("Ask the team for the staging API key", daysAgo: 2.5)
    try fixture.addText(
      "Read the crash log in the sync folder and explain why the retry loop never stops, then propose a fix with a cap of 3 attempts. Include the exact line where the counter resets and say whether the reset is intended.",
      daysAgo: 0.2)
    try fixture.addText("Should the empty state link to the import docs?", daysAgo: 0.1)
    try fixture.reload()
    #expect(fixture.model.visible.count == 7)
    #expect(
      fixture.model.visible.contains {
        if case .malformed = $0 { true } else { false }
      })
    fixture.model.select(noted.file.lastPathComponent, extend: false)
    #expect(fixture.model.selection == [noted.file.lastPathComponent])
    for case .thought(let thought) in fixture.model.visible {
      if case .image(let name, _) = thought.content {
        let url = thought.file.deletingLastPathComponent().appendingPathComponent(name)
        _ = await ThumbnailLoader.load(url)
      }
    }
    let listImage = try Self.image(
      of: fixture.model, input: fixture.input, appearance: appearance, name: "list-\(suffix)")
    #expect(SnapshotTests.colorCount(of: listImage) > SnapshotTests.colorCount(of: emptyImage))
    await ListFixture.settle()
  }

  static func image(
    of model: ListModel, input: InputModel, appearance: NSAppearance.Name, name: String
  ) throws
    -> NSBitmapImageRep
  {
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let url = try SnapshotRenderer.render(
      PanelRootView(preferences: Preferences(defaults: defaults), list: model, input: input),
      size: panelSize, appearance: appearance, name: name)
    let image = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
    #expect(image.pixelsWide == Int(panelSize.width) * SnapshotRenderer.scale)
    #expect(image.pixelsHigh == Int(panelSize.height) * SnapshotRenderer.scale)
    #expect(SnapshotTests.colorCount(of: image) > 1)
    return image
  }
}

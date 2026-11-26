import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct ActionsSnapshotTests {
  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func actionsMenu(_ appearance: NSAppearance.Name) async throws {
    let suffix = appearance == .aqua ? "light" : "dark"
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    try fixture.addText("Renew car registration", daysAgo: 4.01, done: true)
    try fixture.addUnreadable(name: "20261121-140200-k3f9.md", daysAgo: 3)
    try fixture.addText("Ask the team for the staging API key", daysAgo: 2.5)
    let shot = try fixture.addScreenshot(
      note: "Rename fetchUser before the PR", daysAgo: 0.3,
      source: Source(app: "Editor", bundleID: "com.example.editor", window: "users.ts in api"))
    try fixture.addText("Should the empty state link to the import docs?", daysAgo: 0.1)
    try fixture.reload()
    for case .thought(let thought) in fixture.model.visible {
      if let url = thought.imageFileURL { _ = await ThumbnailLoader.load(url) }
    }
    fixture.model.select(shot.file.lastPathComponent, extend: false)
    let closed = try ListSnapshotTests.image(
      of: fixture.model, input: fixture.input, appearance: appearance,
      name: "actions-closed-\(suffix)")
    fixture.model.perform(.actionsMenu)
    #expect(fixture.model.isMenuOpen)
    #expect(fixture.model.focus == .menu)
    #expect(fixture.model.menuItems.count == 8)
    let open = try ListSnapshotTests.image(
      of: fixture.model, input: fixture.input, appearance: appearance,
      name: "actions-menu-\(suffix)")
    #expect(SnapshotTests.colorCount(of: open) > SnapshotTests.colorCount(of: closed))
    await ListFixture.settle()
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func spacePreview(_ appearance: NSAppearance.Name) async throws {
    let suffix = appearance == .aqua ? "light" : "dark"
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    let shot = try fixture.addScreenshot(
      note: "Rename fetchUser before the PR", daysAgo: 0.3,
      source: Source(app: "Editor", bundleID: "com.example.editor", window: "users.ts in api"))
    let text = try fixture.addText(
      "Read the crash log in the sync folder and explain why the retry loop never stops, then propose a fix with a cap of 3 attempts.",
      daysAgo: 0.2, done: true)
    let imageFile = try #require(shot.imageFileURL)
    let image = try #require(PreviewImageLoader.decode(imageFile))
    for (width, layout) in [("", PreviewCardLayout.full), ("-narrowest", .narrowest)] {
      let imageView = PreviewView(thought: shot, image: image, layout: layout)
      let textView = PreviewView(thought: text, image: nil, layout: layout)
      for (name, view) in [("image", AnyView(imageView)), ("text", AnyView(textView))] {
        let size = NSHostingView(rootView: view).fittingSize
        #expect(size.width == layout.width)
        let url = try SnapshotRenderer.render(
          view, size: size, appearance: appearance, name: "preview-\(name)\(width)-\(suffix)")
        let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
        #expect(bitmap.pixelsWide == Int(size.width) * SnapshotRenderer.scale)
        #expect(SnapshotTests.colorCount(of: bitmap) > 1)
      }
    }
  }
}

import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct InputSnapshotTests {
  static func attach(_ fixture: ListFixture) throws {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    #expect(fixture.input.takeImage(from: board))
  }

  static func seed(_ fixture: ListFixture) async throws {
    try fixture.addText("Renew car registration", daysAgo: 4.01, done: true)
    try fixture.addScreenshot(note: "Reword the empty state", daysAgo: 3)
    try fixture.addText("Ask the team for the staging API key", daysAgo: 2.5)
    try fixture.addText("Should the empty state link to the import docs?", daysAgo: 0.1)
    try fixture.reload()
    for case .thought(let thought) in fixture.model.visible {
      if let url = thought.imageFileURL { _ = await ThumbnailLoader.load(url) }
    }
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func inputWithAnAttachment(_ appearance: NSAppearance.Name) async throws {
    let suffix = appearance == .aqua ? "light" : "dark"
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    try await Self.seed(fixture)
    fixture.input.text = "Toast overlaps the header at 390px"
    let plain = try ListSnapshotTests.image(
      of: fixture.model, input: fixture.input, appearance: appearance,
      name: "input-typing-\(suffix)")
    try Self.attach(fixture)
    let attached = try ListSnapshotTests.image(
      of: fixture.model, input: fixture.input, appearance: appearance,
      name: "input-with-image-\(suffix)")
    #expect(SnapshotTests.colorCount(of: attached) != SnapshotTests.colorCount(of: plain))
    await ListFixture.settle()
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func editInPlace(_ appearance: NSAppearance.Name) async throws {
    let suffix = appearance == .aqua ? "light" : "dark"
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    try await Self.seed(fixture)
    let target = try #require(
      fixture.model.visible.compactMap(\.thought).first {
        $0.content == .text("Ask the team for the staging API key")
      })
    let before = try ListSnapshotTests.image(
      of: fixture.model, input: fixture.input, appearance: appearance,
      name: "list-for-edit-\(suffix)")
    fixture.model.select(target.file.lastPathComponent, extend: false)
    fixture.model.perform(.edit)
    #expect(fixture.model.focus == .edit)
    fixture.model.editText = "Ask the team for the staging and prod keys"
    let editing = try ListSnapshotTests.image(
      of: fixture.model, input: fixture.input, appearance: appearance,
      name: "edit-in-place-\(suffix)")
    #expect(SnapshotTests.colorCount(of: editing) != SnapshotTests.colorCount(of: before))
    await ListFixture.settle()
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func searchResultsWithAClearedThought(_ appearance: NSAppearance.Name) async throws {
    let suffix = appearance == .aqua ? "light" : "dark"
    let fixture = try ListFixture(
      recognizer: StubRecognizer("Staging deploy finished, all green"))
    defer { withExtendedLifetime(fixture) {} }
    try fixture.addText(
      "Rotate the staging DB password", daysAgo: 12, done: true,
      source: Source(app: "Terminal", window: "ssh staging-db"))
    _ = try fixture.store.clearDone()
    try fixture.addScreenshot(
      note: "Reword the staging empty state", daysAgo: 3,
      source: Source(app: "Safari", url: URL(string: "https://staging.acme.dev/projects")))
    try fixture.addText(
      "Ask the team for the staging API key", daysAgo: 2.5,
      source: Source(app: "Slack", window: "#infra"))
    try fixture.addText("Renew car registration", daysAgo: 2)
    try fixture.reload()
    for case .thought(let thought) in fixture.model.visible {
      if let url = thought.imageFileURL { _ = await ThumbnailLoader.load(url) }
    }
    let plain = try ListSnapshotTests.image(
      of: fixture.model, input: fixture.input, appearance: appearance,
      name: "list-for-search-\(suffix)")
    fixture.model.query = "staging"
    #expect(fixture.model.visible.count == 3)
    #expect(fixture.model.visible.contains { $0.isCleared })
    #expect(fixture.model.imageExcerpts.values.contains { $0.contains("Staging deploy") })
    let results = try ListSnapshotTests.image(
      of: fixture.model, input: fixture.input, appearance: appearance,
      name: "search-results-\(suffix)")
    #expect(SnapshotTests.colorCount(of: results) != SnapshotTests.colorCount(of: plain))
    await ListFixture.settle()
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func dropTarget(_ appearance: NSAppearance.Name) async throws {
    let suffix = appearance == .aqua ? "light" : "dark"
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    try fixture.reload()
    let idle = try ListSnapshotTests.image(
      of: fixture.model, input: fixture.input, appearance: appearance,
      name: "list-for-drop-\(suffix)")
    fixture.input.isDropTargeted = true
    let targeted = try ListSnapshotTests.image(
      of: fixture.model, input: fixture.input, appearance: appearance, name: "drop-target-\(suffix)"
    )
    #expect(SnapshotTests.colorCount(of: targeted) != SnapshotTests.colorCount(of: idle))
    await ListFixture.settle()
  }
}

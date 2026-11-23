import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct SourceRecordingTests {
  static let page = Source(
    app: "Safari", bundleID: "com.apple.Safari", window: "Example",
    url: URL(
      string: "https://example.com/a"), title: "Example")

  @Test func typedThoughtRecordsTheProvidedSource() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
    defer { board.releaseGlobally() }
    fixture.input.source = { Self.page }
    fixture.input.text = "Read this later"
    await fixture.input.submit()
    let stored = try fixture.store.entries().compactMap(\.thought)
    #expect(stored.first?.source == Self.page)
  }

  @Test func noSourceLeavesTheThoughtWithoutOne() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
    defer { board.releaseGlobally() }
    fixture.input.text = "Plain"
    await fixture.input.submit()
    let stored = try fixture.store.entries().compactMap(\.thought)
    #expect(stored.first?.source == nil)
  }

  @Test func droppedTextRecordsTheProvidedSource() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
    defer { board.releaseGlobally() }
    fixture.input.source = { Self.page }
    board.clearContents()
    board.setString("dropped words", forType: .string)
    #expect(fixture.input.drop(board))
    await ListFixture.settle()
    let stored = try fixture.store.entries().compactMap(\.thought)
    #expect(stored.first?.source == Self.page)
  }

  @Test func droppedFileKeepsItsPathBesideTheProvidedSource() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
    defer { board.releaseGlobally() }
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("notes.txt")
    try Data("hello".utf8).write(to: file)
    fixture.input.source = { Source(app: "Finder", bundleID: "com.apple.finder") }
    board.clearContents()
    board.writeObjects([file as NSURL])
    #expect(fixture.input.drop(board))
    await ListFixture.settle()
    let source = try #require(try fixture.store.entries().compactMap(\.thought).first?.source)
    #expect(source.app == "Finder")
    #expect(source.file == file.path)
  }

  @Test func trackerKeepsTheLastEightDistinctAppsNewestLast() {
    let tracker = FrontmostTracker(ownBundleID: "dev.example.thoughts")
    for pid in 1...10 {
      tracker.record(AppSnapshot(pid: Int32(pid), bundleID: "app.\(pid)", name: "App \(pid)"))
    }
    tracker.record(AppSnapshot(pid: 5, bundleID: "app.5", name: "App 5"))
    #expect(tracker.history.map(\.pid) == [3, 4, 6, 7, 8, 9, 10, 5])
  }

  @Test func pageURLComesFromTheWebAreaThenTheDocument() {
    let webArea = URL(string: "https://example.com/page")
    #expect(BrowserPages.url(webArea: webArea, document: "https://other.test/") == webArea)
    #expect(
      BrowserPages.url(webArea: nil, document: "https://other.test/x")
        == URL(string: "https://other.test/x"))
    #expect(
      BrowserPages.url(webArea: "about:blank", document: "https://other.test/")
        == URL(string: "https://other.test/"))
    #expect(BrowserPages.url(webArea: "favorites://", document: nil) == nil)
    #expect(BrowserPages.url(webArea: nil, document: nil) == nil)
  }

  @Test func blankTitlesAreDropped() {
    #expect(BrowserPages.title("  Example  ") == "Example")
    #expect(BrowserPages.title("   ") == nil)
    #expect(BrowserPages.title(nil) == nil)
  }
}

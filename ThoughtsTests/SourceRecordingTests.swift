import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct SourceRecordingTests {
  static let page = Source(
    app: "Safari", bundleID: "com.apple.Safari", window: "Example",
    url: URL(
      string: "https://example.com/a"), title: "Example")

  @MainActor
  final class Gate {
    var waiting: CheckedContinuation<Void, Never>?

    func wait() async {
      await withCheckedContinuation { waiting = $0 }
    }

    func reached() async -> Bool {
      for _ in 0..<2000 where waiting == nil { await Task.yield() }
      return waiting != nil
    }

    func open() {
      waiting?.resume()
      waiting = nil
    }
  }

  @Test func returnClearsTheFieldBeforeTheSourceResolves() async throws {
    let (fixture, _, _) = try InputModelTests.rig()
    let gate = Gate()
    fixture.input.source = {
      await gate.wait()
      return Self.page
    }
    fixture.input.text = "Slow source"
    let submit = Task { await fixture.input.submit() }
    #expect(await gate.reached())
    #expect(fixture.input.text.isEmpty)
    #expect(try fixture.store.entries().isEmpty)
    gate.open()
    await submit.value
    let stored = try fixture.store.entries().compactMap(\.thought)
    #expect(stored.count == 1)
    #expect(stored.first?.source == Self.page)
  }

  @Test func slowSourceKeepsTheDroppedFilePath() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("slow.txt")
    try Data("hello".utf8).write(to: file)
    let gate = Gate()
    fixture.input.source = {
      await gate.wait()
      return Source(app: "Finder", bundleID: "com.apple.finder")
    }
    board.clearContents()
    board.writeObjects([file as NSURL])
    #expect(fixture.input.drop(board))
    #expect(await gate.reached())
    #expect(try fixture.store.entries().isEmpty)
    gate.open()
    await ListFixture.settle()
    let source = try #require(try fixture.store.entries().compactMap(\.thought).first?.source)
    #expect(source.app == "Finder")
    #expect(source.file == file.path)
  }

  @Test func searchSkipsRolesThatCannotHoldAPage() {
    for role in [
      "AXTable", "AXOutline", "AXList", "AXRow", "AXTextArea", "AXBrowser", "AXScrollBar",
    ] {
      #expect(!BrowserPages.canContainPage(role: role))
    }
    for role in ["AXGroup", "AXScrollArea", "AXSplitGroup"] {
      #expect(BrowserPages.canContainPage(role: role))
    }
  }

  @Test func typedThoughtRecordsTheProvidedSource() async throws {
    let (fixture, _, _) = try InputModelTests.rig()
    fixture.input.source = { Self.page }
    fixture.input.text = "Read this later"
    await fixture.input.submit()
    let stored = try fixture.store.entries().compactMap(\.thought)
    #expect(stored.first?.source == Self.page)
  }

  @Test func noSourceLeavesTheThoughtWithoutOne() async throws {
    let (fixture, _, _) = try InputModelTests.rig()
    fixture.input.text = "Plain"
    await fixture.input.submit()
    let stored = try fixture.store.entries().compactMap(\.thought)
    #expect(stored.first?.source == nil)
  }

  @Test func droppedTextRecordsTheProvidedSource() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
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

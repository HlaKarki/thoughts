import Foundation
import Testing

@testable import ThoughtsCore

private final class InboxFixture {
  let scratch: URL
  let inbox: Inbox
  let folder: URL

  init() throws {
    scratch = FileManager.default.temporaryDirectory
      .appendingPathComponent("inbox-tests-\(UUID().uuidString)", isDirectory: true)
    folder = scratch.appendingPathComponent("Inbox", isDirectory: true)
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    inbox = Inbox(folder: folder)
  }

  deinit {
    try? FileManager.default.removeItem(at: scratch)
  }

  func file(_ name: String, _ data: Data) throws -> URL {
    let url = scratch.appendingPathComponent(name)
    try data.write(to: url)
    return url
  }
}

private let created = Date(timeIntervalSince1970: 1_795_000_000.25)

struct InboxTests {
  @Test func textItemRoundTrips() throws {
    let fixture = try InboxFixture()
    let app = Source(app: "Notes", bundleID: "com.apple.Notes")
    let item = InboxItem(
      kind: .text, text: "Ask about the launch date", sourceApp: app, created: created)
    let entry = try fixture.inbox.write(item, attachment: nil)
    #expect(try fixture.inbox.pending() == [entry])
    let new = try fixture.inbox.newThought(from: entry, source: Source(app: "Fallback"))
    guard case .text(let text) = new.content else {
      Issue.record("expected a text thought")
      return
    }
    #expect(text == "Ask about the launch date")
    #expect(new.source == app)
    #expect(new.created == created)
    try fixture.inbox.remove(entry)
    #expect(try fixture.inbox.pending().isEmpty)
  }

  @Test func urlItemBecomesTextWithSourceURL() throws {
    let fixture = try InboxFixture()
    let page = URL(string: "https://example.com/docs/setup")!
    let item = InboxItem(kind: .url, url: page, title: "Setup guide", created: created)
    let entry = try fixture.inbox.write(item, attachment: nil)
    let fallback = Source(app: "Safari", bundleID: "com.apple.Safari")
    let new = try fixture.inbox.newThought(from: entry, source: fallback)
    guard case .text(let text) = new.content else {
      Issue.record("expected a text thought")
      return
    }
    #expect(text == page.absoluteString)
    #expect(new.source?.url == page)
    #expect(new.source?.title == "Setup guide")
    #expect(new.source?.app == "Safari")
  }

  @Test func imageFileItemBecomesScreenshot() throws {
    let fixture = try InboxFixture()
    let image = try fixture.file("Shot.png", Data([0x89, 0x50, 0x4E, 0x47]))
    let item = InboxItem(kind: .file, originalPath: image.path, created: created)
    let entry = try fixture.inbox.write(item, attachment: image)
    try FileManager.default.removeItem(at: image)
    let new = try fixture.inbox.newThought(from: entry, source: nil)
    guard case .image(.file(let copy), let note) = new.content else {
      Issue.record("expected a screenshot")
      return
    }
    #expect(note.isEmpty)
    #expect(copy.deletingLastPathComponent().standardizedFileURL == entry.standardizedFileURL)
    #expect(FileManager.default.fileExists(atPath: copy.path))
    #expect(new.source?.file == image.path)
  }

  @Test func fileItemKeepsOriginalPath() throws {
    let fixture = try InboxFixture()
    let report = fixture.scratch.appendingPathComponent("Quarterly report.pdf")
    let item = InboxItem(kind: .file, originalPath: report.path, created: created)
    let entry = try fixture.inbox.write(item, attachment: nil)
    let names = try FileManager.default.contentsOfDirectory(atPath: entry.path)
    #expect(names == ["item.json"])
    let new = try fixture.inbox.newThought(from: entry, source: nil)
    guard case .text(let text) = new.content else {
      Issue.record("expected a text thought")
      return
    }
    #expect(text == report.path)
    #expect(new.source?.file == report.path)
  }

  @Test func halfWrittenItemIsSkipped() throws {
    let fixture = try InboxFixture()
    let half = fixture.folder.appendingPathComponent(".partial", isDirectory: true)
    try FileManager.default.createDirectory(at: half, withIntermediateDirectories: true)
    let json = try JSONEncoder().encode(InboxItem(kind: .text, text: "half", created: created))
    try json.write(to: half.appendingPathComponent("item.json"))
    #expect(try fixture.inbox.pending().isEmpty)
  }
}

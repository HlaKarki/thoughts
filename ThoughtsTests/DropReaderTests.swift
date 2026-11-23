import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct DropReaderTests {
  static let now = Date(timeIntervalSince1970: 1_795_000_000)

  static func board() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
  }

  @Test func imageFileDropBecomesScreenshot() throws {
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("capture.png")
    try ListFixture.png().write(to: file)
    let board = Self.board()
    defer { board.releaseGlobally() }
    board.clearContents()
    board.writeObjects([file as NSURL])
    let source = Source(app: "Finder", bundleID: "com.apple.finder")
    let thoughts = DropReader.thoughts(from: board, source: source, now: Self.now)
    #expect(thoughts.count == 1)
    let thought = try #require(thoughts.first)
    guard case .image(.file(let stored), let note) = thought.content else {
      Issue.record("expected an image file thought")
      return
    }
    #expect(stored.lastPathComponent == "capture.png")
    #expect(note.isEmpty)
    #expect(thought.created == Self.now)
    #expect(thought.source?.app == "Finder")
    #expect(thought.source?.file?.hasSuffix("capture.png") == true)
  }

  @Test func textDropBecomesTextThought() {
    let board = Self.board()
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setString("  Ask for the staging key  \n", forType: .string)
    let thoughts = DropReader.thoughts(from: board, source: nil, now: Self.now)
    #expect(thoughts.count == 1)
    guard case .text(let text) = thoughts.first?.content else {
      Issue.record("expected a text thought")
      return
    }
    #expect(text == "Ask for the staging key")
    #expect(thoughts.first?.source == nil)
  }

  @Test func imageDataDropBecomesScreenshot() throws {
    let board = Self.board()
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    let thoughts = DropReader.thoughts(from: board, source: nil, now: Self.now)
    guard case .image(.data(_, let type), _) = thoughts.first?.content else {
      Issue.record("expected an image data thought")
      return
    }
    #expect(type == .png)
  }

  @Test func pdfDropBecomesPathThoughtWithSourceFile() throws {
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("report.pdf")
    try Data("%PDF-1.4".utf8).write(to: file)
    let board = Self.board()
    defer { board.releaseGlobally() }
    board.clearContents()
    board.writeObjects([file as NSURL])
    let thoughts = DropReader.thoughts(from: board, source: nil, now: Self.now)
    let thought = try #require(thoughts.first)
    guard case .text(let text) = thought.content else {
      Issue.record("expected a path thought")
      return
    }
    #expect(text.hasSuffix("report.pdf"))
    #expect(thought.source?.file == text)
  }

  @Test func emptyBoardGivesNothing() {
    let board = Self.board()
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setString("   ", forType: .string)
    #expect(DropReader.thoughts(from: board, source: nil, now: Self.now).isEmpty)
  }

  @Test func aFinderStyleDropOfAnImageFileKeepsTheFileNotItsIcon() throws {
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("capture.png")
    try ListFixture.png().write(to: file)
    let board = Self.board()
    defer { board.releaseGlobally() }
    try InputModelTests.fill(board, file: file, image: true)
    let thoughts = DropReader.thoughts(from: board, source: nil, now: Self.now)
    #expect(thoughts.count == 1)
    guard case .image(.file(let stored), _) = thoughts.first?.content else {
      Issue.record("expected the image file")
      return
    }
    #expect(stored.lastPathComponent == "capture.png")
  }
}

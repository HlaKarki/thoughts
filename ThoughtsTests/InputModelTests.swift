import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct InputModelTests {
  final class Saves {
    var all: [ManualSave] = []
    var failures: [String] = []
  }

  static func rig() throws -> (fixture: ListFixture, saves: Saves, board: NSPasteboard) {
    let fixture = try ListFixture()
    let saves = Saves()
    fixture.input.onManualSave = { saves.all.append($0) }
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    return (fixture, saves, board)
  }

  @Test func enterAddsTheTrimmedTextAndAnEmptyInputDoesNothing() async throws {
    let (fixture, saves, board) = try Self.rig()
    defer { board.releaseGlobally() }
    fixture.input.text = "   \n "
    await fixture.input.submit()
    #expect(try fixture.store.entries().isEmpty)
    #expect(saves.all.isEmpty)
    fixture.input.text = "  Ask the team for the staging API key \n"
    await fixture.input.submit()
    let stored = try fixture.store.entries().compactMap(\.thought)
    #expect(stored.count == 1)
    #expect(stored.first?.content == .text("Ask the team for the staging API key"))
    #expect(fixture.input.text.isEmpty)
    #expect(saves.all.map(\.file) == stored.map(\.file))
  }

  @Test func pastedImageAttachesAndTheTextBecomesItsNote() async throws {
    let (fixture, saves, board) = try Self.rig()
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    fixture.input.paste(board)
    #expect(fixture.input.attachment != nil)
    #expect(fixture.input.text.isEmpty)
    fixture.input.text = " Toast overlaps the header "
    await fixture.input.submit()
    #expect(fixture.input.attachment == nil)
    let stored = try fixture.store.entries().compactMap(\.thought)
    guard case .image(let name, let note) = stored.first?.content else {
      Issue.record("expected a screenshot")
      return
    }
    #expect(note == "Toast overlaps the header")
    #expect(name.hasSuffix(".png"))
    #expect(saves.all.first?.pasteboardChangeCount == board.changeCount)
  }

  @Test func imageOnlyAttachmentAddsWithAnEmptyNote() async throws {
    let (fixture, _, board) = try Self.rig()
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    fixture.input.paste(board)
    await fixture.input.submit()
    let stored = try fixture.store.entries().compactMap(\.thought)
    guard case .image(_, let note) = stored.first?.content else {
      Issue.record("expected a screenshot")
      return
    }
    #expect(note.isEmpty)
  }

  @Test func pastedTextGoesIntoTheFieldAndRemoveClearsTheImage() throws {
    let (fixture, _, board) = try Self.rig()
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setString("a copied line", forType: .string)
    fixture.input.paste(board)
    #expect(fixture.input.text == "a copied line")
    #expect(fixture.input.attachment == nil)
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    #expect(fixture.input.takeImage(from: board))
    fixture.input.removeAttachment()
    #expect(fixture.input.attachment == nil)
  }

  @Test func droppedFilesAndTextAreAddedAtOnce() async throws {
    let (fixture, saves, board) = try Self.rig()
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setString("dropped words", forType: .string)
    #expect(fixture.input.drop(board))
    await ListFixture.settle()
    let stored = try fixture.store.entries().compactMap(\.thought)
    #expect(stored.map(\.content) == [.text("dropped words")])
    #expect(saves.all.count == 1)
    #expect(saves.all.first?.pasteboardChangeCount == nil)
    board.clearContents()
    #expect(!fixture.input.drop(board))
  }

  @Test func aDroppedFileReportsItsSourceFileInTheManualSave() async throws {
    let (fixture, saves, board) = try Self.rig()
    defer { board.releaseGlobally() }
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("capture.png")
    try ListFixture.png().write(to: file)
    board.clearContents()
    board.writeObjects([file as NSURL])
    #expect(fixture.input.drop(board))
    await ListFixture.settle()
    let save = try #require(saves.all.first)
    #expect(save.sourceFile?.path == file.path)
    #expect(save.file.pathExtension == "md")
  }

  static func fill(_ board: NSPasteboard, file: URL? = nil, text: String? = nil, image: Bool) throws
  {
    board.clearContents()
    if let file { board.writeObjects([file as NSURL]) }
    if let text {
      board.addTypes([.string], owner: nil)
      board.setString(text, forType: .string)
    }
    if image {
      let tiff = try #require(NSImage(data: try ListFixture.png())?.tiffRepresentation)
      board.addTypes([.tiff], owner: nil)
      board.setData(tiff, forType: .tiff)
    }
  }

  @Test func anImageFileCopiedInFinderAttachesThatFileNotItsIcon() async throws {
    let (fixture, _, board) = try Self.rig()
    defer { board.releaseGlobally() }
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("capture.png")
    try ListFixture.png().write(to: file)
    try Self.fill(board, file: file, image: true)
    fixture.input.paste(board)
    await fixture.input.pasteRead?.value
    guard case .image(.file(let attached), _) = fixture.input.attachment else {
      Issue.record("expected the image file")
      return
    }
    #expect(attached.lastPathComponent == "capture.png")
  }

  @Test func aNonImageFileCopiedInFinderAttachesNothingFromItsIcon() throws {
    let (fixture, _, board) = try Self.rig()
    defer { board.releaseGlobally() }
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("report.pdf")
    try Data("%PDF-1.4".utf8).write(to: file)
    try Self.fill(board, file: file, image: true)
    #expect(!fixture.input.takeImage(from: board))
    fixture.input.paste(board)
    #expect(fixture.input.attachment == nil)
  }

  @Test func copiedCellTextGoesIntoTheFieldEvenWithAPictureBesideIt() throws {
    let (fixture, _, board) = try Self.rig()
    defer { board.releaseGlobally() }
    try Self.fill(board, text: "Q3\t4200", image: true)
    #expect(!fixture.input.takeImage(from: board))
    fixture.input.paste(board)
    #expect(fixture.input.text == "Q3\t4200")
    #expect(fixture.input.attachment == nil)
  }

  @Test func aBrowserCopyImageAttachesThePictureNotItsAddress() throws {
    let (fixture, _, board) = try Self.rig()
    defer { board.releaseGlobally() }
    try Self.fill(board, text: "https://example.com/cat.png", image: true)
    fixture.input.paste(board)
    #expect(fixture.input.attachment != nil)
    #expect(fixture.input.text.isEmpty)
  }

  @Test func aCopiedLinkWithNoPictureIsText() throws {
    let (fixture, _, board) = try Self.rig()
    defer { board.releaseGlobally() }
    try Self.fill(board, text: "https://example.com/cat.png", image: false)
    fixture.input.paste(board)
    #expect(fixture.input.text == "https://example.com/cat.png")
    #expect(fixture.input.attachment == nil)
  }

  @Test func pictureDataWithNoTextAttaches() throws {
    let (fixture, _, board) = try Self.rig()
    defer { board.releaseGlobally() }
    try Self.fill(board, image: true)
    fixture.input.paste(board)
    #expect(fixture.input.attachment != nil)
    #expect(fixture.input.text.isEmpty)
  }
}

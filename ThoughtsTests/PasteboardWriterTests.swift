import AppKit
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct PasteboardWriterTests {
  static func privateBoard() -> NSPasteboard {
    Throwaway.pasteboard()
  }

  @Test func copyImageWritesPNGAndFileURL() async throws {
    let board = Self.privateBoard()
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("shot.png")
    let png = try ListFixture.png()
    try png.write(to: file)
    let writer = PasteboardWriter(pasteboard: board)
    await writer.write(imageAt: file)
    #expect(board.data(forType: .png) == png)
    #expect(board.string(forType: .fileURL) == file.absoluteString)
    #expect(board.string(forType: .string) == nil)
  }

  @Test func copyImageConvertsOtherFormatsToPNG() async throws {
    let board = Self.privateBoard()
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("shot.tiff")
    let tiff = try #require(NSBitmapImageRep(data: try ListFixture.png())?.tiffRepresentation)
    try tiff.write(to: file)
    await PasteboardWriter(pasteboard: board).write(imageAt: file)
    let written = try #require(board.data(forType: .png))
    #expect(written.starts(with: [0x89, 0x50, 0x4E, 0x47]))
  }

  @Test func anImageReadThatLandsAfterTheClipboardMovedWritesNothing() async throws {
    let board = Self.privateBoard()
    let hold = Hold()
    defer { hold.release() }
    let png = try ListFixture.png()
    let writer = PasteboardWriter(
      pasteboard: board,
      readImage: { _ in
        hold.pass()
        return .png(png)
      })
    var reported: [Int] = []
    writer.onOwnChange = { reported.append($0) }
    let writing = Task { await writer.write(imageAt: URL(fileURLWithPath: "/example/shot.png")) }
    await hold.waitForArrivals(1)
    board.clearContents()
    board.setString("moved", forType: .string)
    hold.release()
    let outcome = await writing.value
    #expect(outcome == .superseded)
    #expect(board.string(forType: .string) == "moved")
    #expect(board.data(forType: .png) == nil)
    #expect(reported.isEmpty)
  }

  @Test func writesRecordOwnChangeCount() {
    let board = Self.privateBoard()
    let writer = PasteboardWriter(pasteboard: board)
    var reported: [Int] = []
    writer.onOwnChange = { reported.append($0) }
    writer.write(text: "first")
    let first = board.changeCount
    writer.write(text: "second")
    let second = board.changeCount
    #expect(board.string(forType: .string) == "second")
    #expect(writer.ownChangeCounts == [first, second])
    #expect(reported == [first, second])
  }

  @Test func noteOwnRecordsAndReports() {
    let writer = PasteboardWriter(pasteboard: Self.privateBoard())
    var reported: [Int] = []
    writer.onOwnChange = { reported.append($0) }
    writer.noteOwn(41)
    #expect(writer.ownChangeCounts == [41])
    #expect(reported == [41])
  }

  @Test func ownWritesNeverBecomeOffers() throws {
    let board = Self.privateBoard()
    let writer = PasteboardWriter(pasteboard: board)
    var queue = OfferQueue()
    writer.onOwnChange = { queue.noteOwn(changeCount: $0) }
    let now = Date(timeIntervalSince1970: 1_795_000_000)
    _ = queue.add(.clipboard(changeCount: 90, file: nil, at: now), source: nil)
    writer.noteOwn(90)
    #expect(queue.current == nil)
    writer.write(text: "copied by thoughts")
    let written = board.changeCount
    let update = queue.add(.clipboard(changeCount: written, file: nil, at: now), source: nil)
    #expect(update == .ignore)
  }
}

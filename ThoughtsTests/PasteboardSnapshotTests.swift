import AppKit
import Testing

@testable import Thoughts

@MainActor
struct PasteboardSnapshotTests {
  static let custom = NSPasteboard.PasteboardType("dev.example.thoughts.test-payload")

  static func privateBoard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
  }

  static func fill(_ board: NSPasteboard) {
    board.clearContents()
    let first = NSPasteboardItem()
    first.setString("first item", forType: .string)
    first.setData(Data([1, 2, 3, 4]), forType: custom)
    let second = NSPasteboardItem()
    second.setString("second item", forType: .string)
    board.writeObjects([first, second])
  }

  static func contents(of board: NSPasteboard) -> [[String: Data]] {
    (board.pasteboardItems ?? []).map { item in
      Dictionary(
        uniqueKeysWithValues: item.types.compactMap { type in
          item.data(forType: type).map { (type.rawValue, $0) }
        })
    }
  }

  @Test func snapshotRestoresEveryItemAndType() {
    let board = Self.privateBoard()
    defer { board.releaseGlobally() }
    Self.fill(board)
    let before = Self.contents(of: board)
    let snapshot = PasteboardSnapshot.take(board)
    board.clearContents()
    board.setString("something else", forType: .string)
    let count = snapshot.restore(to: board)
    #expect(count == board.changeCount)
    #expect(Self.contents(of: board) == before)
    #expect(before.count == 2)
    #expect(before[0][Self.custom.rawValue] == Data([1, 2, 3, 4]))
  }

  @Test func restoringAnEmptySnapshotEmptiesTheBoard() {
    let board = Self.privateBoard()
    defer { board.releaseGlobally() }
    board.clearContents()
    let snapshot = PasteboardSnapshot.take(board)
    board.setString("copied", forType: .string)
    _ = snapshot.restore(to: board)
    #expect(board.pasteboardItems?.isEmpty ?? true)
  }

  @Test func copyReadsTheSelectionAndPutsTheClipboardBack() async {
    let board = Self.privateBoard()
    defer { board.releaseGlobally() }
    Self.fill(board)
    let before = Self.contents(of: board)
    let reader = SelectionReader(
      pasteboard: board,
      postCopy: {
        board.clearContents()
        board.setString("the selection", forType: .string)
      },
      secureInput: { false })
    let (probe, counts) = await reader.copySelection()
    #expect(probe == .text("the selection"))
    #expect(Self.contents(of: board) == before)
    #expect(counts.last == board.changeCount)
    #expect(counts.count >= 2)
  }

  @Test func copyWithNoChangeFindsNothingAndTouchesNothing() async {
    let board = Self.privateBoard()
    defer { board.releaseGlobally() }
    Self.fill(board)
    let count = board.changeCount
    let reader = SelectionReader(pasteboard: board, postCopy: {}, secureInput: { false })
    let (probe, counts) = await reader.copySelection()
    #expect(probe == .copiedNothing)
    #expect(counts.isEmpty)
    #expect(board.changeCount == count)
  }

  @Test func copyOfNonTextIsRestoredAndCountsAsNothing() async {
    let board = Self.privateBoard()
    defer { board.releaseGlobally() }
    Self.fill(board)
    let before = Self.contents(of: board)
    let reader = SelectionReader(
      pasteboard: board,
      postCopy: {
        board.clearContents()
        board.setData(Data([9]), forType: .png)
      },
      secureInput: { false })
    let (probe, counts) = await reader.copySelection()
    #expect(probe == .copiedNothing)
    #expect(Self.contents(of: board) == before)
    #expect(counts.last == board.changeCount)
  }
}

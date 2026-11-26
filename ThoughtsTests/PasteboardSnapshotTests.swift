import AppKit
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct PasteboardSnapshotTests {
  static let custom = NSPasteboard.PasteboardType("dev.example.thoughts.test-payload")

  static func privateBoard() -> NSPasteboard {
    Throwaway.pasteboard()
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
    board.clearContents()
    let snapshot = PasteboardSnapshot.take(board)
    board.setString("copied", forType: .string)
    _ = snapshot.restore(to: board)
    #expect(board.pasteboardItems?.isEmpty ?? true)
  }

  @Test func copyReadsTheSelectionAndPutsTheClipboardBack() async {
    let board = Self.privateBoard()
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
    #expect(counts.count == 2)
  }

  @Test func copyReportsOnlyTheCopyAndTheRestore() async {
    let board = Self.privateBoard()
    Self.fill(board)
    let before = board.changeCount
    var settled = 0
    let reader = SelectionReader(
      pasteboard: board,
      postCopy: {
        board.clearContents()
        board.setString("first", forType: .string)
        board.clearContents()
        board.setString("the selection", forType: .string)
        settled = board.changeCount
      },
      secureInput: { false })
    let (_, counts) = await reader.copySelection()
    #expect(counts == [settled, board.changeCount])
    #expect(!counts.contains(before + 1))
  }

  @Test func copyWithNoChangeFindsNothingAndTouchesNothing() async {
    let board = Self.privateBoard()
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

  @Test func aConcealedCopyIsRestoredAndNeverRead() async {
    let board = Self.privateBoard()
    Self.fill(board)
    let before = Self.contents(of: board)
    let reader = SelectionReader(
      pasteboard: board,
      postCopy: {
        board.clearContents()
        board.setString("hunter2", forType: .string)
        board.setData(Data(), forType: NSPasteboard.PasteboardType(ClipboardTypes.concealed))
      },
      secureInput: { false })
    let (probe, counts) = await reader.copySelection()
    #expect(probe == .secureField)
    #expect(Self.contents(of: board) == before)
    #expect(counts.last == board.changeCount)
  }

  @Test func aConcealedOrTransientClipboardSkipsTheCopyAndTouchesNothing() async {
    for marker in [ClipboardTypes.concealed, ClipboardTypes.transient] {
      let board = Self.privateBoard()
      board.clearContents()
      board.setString("hunter2", forType: .string)
      board.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
      let before = Self.contents(of: board)
      let count = board.changeCount
      var posted = 0
      let reader = SelectionReader(
        pasteboard: board, postCopy: { posted += 1 }, secureInput: { false })
      let (probe, counts) = await reader.copySelection()
      #expect(probe == .copiedNothing)
      #expect(counts.isEmpty)
      #expect(posted == 0)
      #expect(board.changeCount == count)
      #expect(Self.contents(of: board) == before)
    }
  }
}

import AppKit
import Carbon.HIToolbox
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct CopyKeyCodeTests {
  @Test func qwertyUsesTheCKey() {
    let code = CopyKeyCode.find { $0 == CGKeyCode(kVK_ANSI_C) ? "c" : "x" }
    #expect(code == CGKeyCode(kVK_ANSI_C))
  }

  @Test func dvorakPicksTheKeyThatTypesCWithCommand() {
    let layout: [CGKeyCode: String] = [
      CGKeyCode(kVK_ANSI_J): "c", CGKeyCode(kVK_ANSI_C): "j", CGKeyCode(kVK_ANSI_V): "k",
    ]
    #expect(CopyKeyCode.find { layout[$0] } == CGKeyCode(kVK_ANSI_J))
  }

  @Test func layoutWithoutACFallsBackToTheCKey() {
    #expect(CopyKeyCode.find { _ in "x" } == CGKeyCode(kVK_ANSI_C))
    #expect(CopyKeyCode.find { _ in nil } == CGKeyCode(kVK_ANSI_C))
  }

  @Test func theCurrentLayoutsChosenKeyTypesCWithCommand() throws {
    let layout = try #require(CopyKeyCode.commandLayout())
    #expect(CopyKeyCode.translate(CopyKeyCode.current(), layout: layout) == "c")
  }

  @Test func secureInputWithAnUnreadableFocusIsASecureField() {
    let reader = AXReader(secureInput: { true })
    #expect(reader.selection(pid: 1) == .secureField)
  }

  @Test func secureInputTurningOnBeforeThePostPostsNothing() async {
    let board = PasteboardSnapshotTests.privateBoard()
    defer { board.releaseGlobally() }
    PasteboardSnapshotTests.fill(board)
    let count = board.changeCount
    var posts = 0
    let reader = SelectionReader(
      pasteboard: board, postCopy: { posts += 1 }, secureInput: { true })
    let (probe, counts) = await reader.copySelection()
    #expect(probe == .secureField)
    #expect(counts.isEmpty)
    #expect(posts == 0)
    #expect(board.changeCount == count)
  }
}

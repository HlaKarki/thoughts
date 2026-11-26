import AppKit
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized, .throwaway)
struct StorageGonePanelTests {
  @Test func aFolderRenamedAwayShowsTheMessageHoldsItsRowsAndComesBackOnItsOwn() async throws {
    try await PanelHarness.run(storageRetry: .milliseconds(50)) { harness in
      try harness.seed(["Call the landlord", "Buy oat milk"])
      harness.list.start()
      try await harness.show()
      let folder = harness.fixture.folder
      let away = folder.deletingLastPathComponent()
        .appendingPathComponent("Away", isDirectory: true)
      try FileManager.default.moveItem(at: folder, to: away)
      harness.list.panelDidHide()
      try await harness.show()
      #expect(await PanelHarness.waitUntil { harness.list.storageProblem != nil })
      await harness.settle("after the folder went away")
      #expect(harness.list.shownFeedback?.text == StorageProblemTests.message)
      #expect(harness.list.visible.count == 2)
      await harness.press(.up)
      #expect(harness.list.selection.count == 1)
      await harness.press(.character("c"), .command)
      #expect(harness.board.string(forType: .string) == nil)
      await harness.press(.delete, .command)
      #expect(harness.trash.all.isEmpty)
      #expect(harness.list.visible.count == 2)
      #expect(harness.list.shownFeedback?.text == StorageProblemTests.message)
      try FileManager.default.moveItem(at: away, to: folder)
      #expect(await PanelHarness.waitUntil { harness.list.storageProblem == nil })
      await harness.settle("after the folder came back")
      #expect(try harness.storedTexts.sorted() == ["Buy oat milk", "Call the landlord"])
      #expect(harness.list.visible.count == 2)
      await harness.press(.character("c"), .command)
      #expect(harness.board.string(forType: .string) == "Buy oat milk")
    }
  }
}

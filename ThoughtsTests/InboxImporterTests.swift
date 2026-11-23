import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct InboxImporterTests {
  final class Saves {
    var failing = true
    var saved: [NewThought] = []
    var failures: [String] = []
  }

  @Test func failedAddLeavesTheItemInTheInbox() async throws {
    let temp = TempFolder()
    let inbox = Inbox(folder: temp.url.appendingPathComponent("Inbox", isDirectory: true))
    let entry = try inbox.write(InboxItem(kind: .text, text: "Call the dentist"), attachment: nil)
    let saves = Saves()
    let importer = InboxImporter(
      inbox: inbox,
      save: { new in
        if saves.failing { throw ThoughtsError.storageUnavailable("/Volumes/Notes/Thoughts") }
        saves.saved.append(new)
      },
      source: { nil })
    importer.onFailure = { saves.failures.append($0) }
    await importer.importNow().value
    #expect(try inbox.pending() == [entry])
    #expect(
      saves.failures == [ListModel.message(for: .storageUnavailable("/Volumes/Notes/Thoughts"))])
    saves.failing = false
    await importer.importNow().value
    #expect(try inbox.pending().isEmpty)
    #expect(saves.saved.count == 1)
    #expect(saves.failures.count == 1)
  }
}

import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct ListModelTests {
  @Test func selectionKeepsTheAnchorFirstAndClampsAtTheEnds() throws {
    let fixture = try ListFixture()
    for (offset, text) in ["a", "b", "c", "d"].enumerated() {
      try fixture.addText(text, daysAgo: Double(5 - offset))
    }
    try fixture.reload()
    let names = fixture.model.visible.map(\.fileName)
    fixture.model.moveSelection(by: 1, extend: false)
    #expect(fixture.model.selection == [names[0]])
    fixture.model.select(names[1], extend: false)
    fixture.model.moveSelection(by: 2, extend: true)
    #expect(fixture.model.selection == [names[1], names[2], names[3]])
    fixture.model.moveSelection(by: -5, extend: true)
    #expect(fixture.model.selection == [names[1], names[0]])
    fixture.model.moveSelection(by: 9, extend: false)
    #expect(fixture.model.selection == [names[3]])
  }

  @Test func clearedThoughtsShowOnlyWhileSearching() throws {
    let fixture = try ListFixture()
    try fixture.addText("keep this one", daysAgo: 2)
    try fixture.addText("archive this one", daysAgo: 1, done: true)
    _ = try fixture.store.clearDone()
    try fixture.reload()
    #expect(fixture.model.visible.count == 1)
    fixture.model.query = "archive"
    #expect(fixture.model.visible.count == 1)
    #expect(fixture.model.visible.first?.isCleared == true)
    fixture.model.query = ""
    #expect(fixture.model.visible.first?.isCleared == false)
  }

  @Test func updatedNamesTheModelDoesNotHoldBecomeAdds() throws {
    let fixture = try ListFixture()
    try fixture.addText("first", daysAgo: 2)
    try fixture.reload()
    #expect(fixture.model.entries.count == 1)
    let late = try fixture.addText("second", daysAgo: 1)
    _ = try fixture.sync.reconcile(nil)
    let name = late.file.lastPathComponent
    fixture.model.apply(IndexChanges(updated: [name]))
    #expect(fixture.model.entries.count == 2)
    #expect(fixture.model.addedCount == 1)
    fixture.model.apply(IndexChanges(removed: ["gone.md"]))
    #expect(fixture.model.entries.count == 2)
    #expect(fixture.model.addedCount == 1)
  }
}

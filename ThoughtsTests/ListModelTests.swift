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

  @Test func hintStaysWhileThePanelIsHidden() async throws {
    let fixture = try ListFixture()
    fixture.model.showHint("The folder is unavailable")
    try await Task.sleep(for: .milliseconds(150))
    #expect(fixture.model.hint == "The folder is unavailable")
    fixture.model.panelDidShow()
    #expect(fixture.model.hint == "The folder is unavailable")
    fixture.model.panelDidHide()
    #expect(fixture.model.hint == "The folder is unavailable")
  }

  @Test func actionsMenuFiltersRunsAndHandsTheCommandOn() throws {
    let fixture = try ListFixture()
    let thought = try fixture.addText("one", daysAgo: 1)
    try fixture.reload()
    var forwarded: [KeyCommand] = []
    fixture.model.onCommand = { forwarded.append($0) }
    fixture.model.perform(.actionsMenu)
    #expect(!fixture.model.isMenuOpen)
    fixture.model.select(thought.file.lastPathComponent, extend: false)
    fixture.model.perform(.actionsMenu)
    #expect(fixture.model.isMenuOpen)
    #expect(fixture.model.focus == .menu)
    fixture.model.menuQuery = "mark"
    #expect(fixture.model.menuItems.map(\.id) == ["toggleDone"])
    fixture.model.perform(.menuMove(5))
    #expect(fixture.model.menuHighlight == 0)
    fixture.model.perform(.menuRun)
    #expect(!fixture.model.isMenuOpen)
    #expect(fixture.model.focus == .list)
    #expect(fixture.model.menuQuery.isEmpty)
    #expect(forwarded == [.toggleDone])
    fixture.model.perform(.actionsMenu)
    fixture.model.perform(.menuClose)
    #expect(fixture.model.focus == .list)
    #expect(forwarded == [.toggleDone])
  }

  @Test func previewFollowsTheSelectionAndClosesOnEsc() throws {
    let fixture = try ListFixture()
    let first = try fixture.addText("one", daysAgo: 2)
    let second = try fixture.addText("two", daysAgo: 1)
    try fixture.reload()
    var shown: [String?] = []
    fixture.model.onPreviewChange = { shown.append($0.map { $0.file.lastPathComponent }) }
    fixture.model.perform(.preview)
    #expect(!fixture.model.isPreviewing)
    fixture.model.select(first.file.lastPathComponent, extend: false)
    fixture.model.perform(.preview)
    #expect(fixture.model.isPreviewing)
    fixture.model.perform(.move(1))
    #expect(fixture.model.previewThought?.id == second.id)
    fixture.model.perform(.backToInput)
    #expect(!fixture.model.isPreviewing)
    #expect(fixture.model.selection == [second.file.lastPathComponent])
    #expect(
      shown == [
        first.file.lastPathComponent, second.file.lastPathComponent, nil,
      ])
  }

  private static func seeded() throws -> (fixture: ListFixture, oldest: String, newest: String) {
    let fixture = try ListFixture()
    let first = try fixture.addText("one", daysAgo: 3)
    try fixture.addText("two", daysAgo: 2)
    let last = try fixture.addText("three", daysAgo: 1)
    try fixture.reload()
    return (fixture, first.file.lastPathComponent, last.file.lastPathComponent)
  }

  @Test func downOnTheNewestRowMovesToTheInputAndClearsTheSelection() throws {
    let seed = try Self.seeded()
    let model = seed.fixture.model
    model.select(seed.newest, extend: false)
    model.perform(.move(1))
    #expect(model.focus == .input)
    #expect(model.selection.isEmpty)
  }

  @Test func upOnTheOldestRowMovesToSearchAndClearsTheSelection() throws {
    let seed = try Self.seeded()
    let model = seed.fixture.model
    model.select(seed.oldest, extend: false)
    model.perform(.move(-1))
    #expect(model.focus == .search)
    #expect(model.selection.isEmpty)
  }

  @Test func arrowsInTheMiddleOfTheListStayInTheList() throws {
    let seed = try Self.seeded()
    let model = seed.fixture.model
    model.select(seed.oldest, extend: false)
    model.perform(.move(1))
    #expect(model.focus == .list)
    #expect(model.selection.count == 1)
    model.perform(.move(-1))
    #expect(model.focus == .list)
    #expect(model.selection == [seed.oldest])
  }

  @Test func leavingTheListByArrowClosesThePreview() throws {
    let seed = try Self.seeded()
    let model = seed.fixture.model
    model.select(seed.newest, extend: false)
    model.perform(.preview)
    #expect(model.isPreviewing)
    model.perform(.move(1))
    #expect(!model.isPreviewing)
    model.select(seed.oldest, extend: false)
    model.perform(.preview)
    model.perform(.move(-1))
    #expect(!model.isPreviewing)
  }

  @Test func shiftArrowsStayClampedAtTheEnds() throws {
    let seed = try Self.seeded()
    let model = seed.fixture.model
    model.select(seed.newest, extend: false)
    model.perform(.extend(1))
    #expect(model.focus == .list)
    #expect(model.selection == [seed.newest])
    model.select(seed.oldest, extend: false)
    model.perform(.extend(-1))
    #expect(model.focus == .list)
    #expect(model.selection == [seed.oldest])
  }

  @Test func downFromSearchWithTheNewestSelectedGoesToTheList() throws {
    let seed = try Self.seeded()
    let model = seed.fixture.model
    model.select(seed.newest, extend: false)
    model.perform(.focusSearch)
    model.perform(.move(1))
    #expect(model.focus == .list)
    #expect(model.selection == [seed.newest])
  }

  @Test func typingInTheListGoesToTheInput() throws {
    let seed = try Self.seeded()
    let model = seed.fixture.model
    var forwarded: [KeyCommand] = []
    model.onCommand = { forwarded.append($0) }
    model.select(seed.newest, extend: false)
    model.perform(.preview)
    model.perform(.type("x"))
    #expect(model.focus == .input)
    #expect(model.selection.isEmpty)
    #expect(!model.isPreviewing)
    #expect(forwarded == [.type("x")])
    #expect(model.query.isEmpty)
  }

  @Test func typingInTheListWithAQueryGoesToTheSearch() throws {
    let seed = try Self.seeded()
    let model = seed.fixture.model
    var forwarded: [KeyCommand] = []
    model.onCommand = { forwarded.append($0) }
    model.query = "t"
    model.select(model.visible.map(\.fileName)[0], extend: false)
    model.perform(.type("w"))
    #expect(model.focus == .search)
    #expect(model.selection.isEmpty)
    #expect(model.query == "tw")
    #expect(forwarded.isEmpty)
  }

  @Test func clickingOutOfTheListClosesThePreview() throws {
    let seed = try Self.seeded()
    let model = seed.fixture.model
    model.select(seed.newest, extend: false)
    model.perform(.preview)
    model.focus = .input
    #expect(!model.isPreviewing)
  }
}

import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

struct ActionCatalogTests {
  static func thought(
    _ content: ThoughtContent = .text("Ask the team for the staging key"),
    done: Date? = nil,
    source: Source? = nil
  ) -> ThoughtEntry {
    .thought(
      Thought(
        id: ThoughtID.random(),
        created: Date(timeIntervalSince1970: 1_795_000_000),
        done: done,
        content: content,
        source: source,
        file: URL(fileURLWithPath: "/tmp/thoughts-catalog/20261101-0900-a1b2.md"),
        version: FileVersion(modified: .distantPast, size: 0)))
  }

  static func ids(_ items: [ActionItem]) -> [String] { items.map(\.id) }

  @Test func filterMatchesSubstringIgnoringCase() {
    let items = ActionCatalog.items(for: [Self.thought()])
    #expect(Self.ids(ActionCatalog.filter(items, by: "FIND")) == ["showInFinder"])
    #expect(Self.ids(ActionCatalog.filter(items, by: "copy")) == ["copy", "copyPath"])
    #expect(ActionCatalog.filter(items, by: "").count == items.count)
    #expect(ActionCatalog.filter(items, by: "zzz").isEmpty)
  }

  @Test func warningRowOffersOnlyFinderAndCopyPath() {
    let broken = ThoughtEntry.malformed(
      file: URL(fileURLWithPath: "/tmp/thoughts-catalog/broken.md"), reason: "bad front matter")
    #expect(Self.ids(ActionCatalog.items(for: [broken])) == ["copyPath", "showInFinder"])
    #expect(
      Self.ids(ActionCatalog.items(for: [broken, Self.thought()])) == ["copyPath", "showInFinder"])
  }

  @Test func doneThoughtOffersMarkNotDone() {
    let done = Self.thought(done: Date())
    let open = Self.thought()
    func title(_ selection: [ThoughtEntry]) -> String? {
      ActionCatalog.items(for: selection).first { $0.id == "toggleDone" }?.title
    }
    #expect(title([done]) == "Mark not done")
    #expect(title([open]) == "Mark done")
    #expect(title([done, open]) == "Mark done")
    #expect(title([done, Self.thought(done: Date())]) == "Mark not done")
  }

  @Test func missingSourceHidesOpenSource() {
    func hasOpen(_ source: Source?) -> Bool {
      ActionCatalog.items(for: [Self.thought(source: source)]).contains { $0.id == "openSource" }
    }
    #expect(!hasOpen(nil))
    #expect(!hasOpen(Source(app: "Notes", window: "Groceries")))
    #expect(hasOpen(Source(bundleID: "com.example.notes")))
    #expect(hasOpen(Source(url: URL(string: "https://example.com/page"))))
    #expect(hasOpen(Source(file: "/tmp/original.txt")))
  }

  @Test func menuFollowsTheDrawnOrder() {
    let screenshot = Self.thought(
      .image(fileName: "shot.png", note: ""), source: Source(bundleID: "com.example.editor"))
    let items = ActionCatalog.items(for: [screenshot])
    #expect(
      Self.ids(items) == [
        "copy", "copyPath", "edit", "toggleDone", "preview", "openSource", "showInFinder",
        "delete",
      ])
    #expect(items.first?.title == "Copy")
    #expect(items.last?.destructive == true)
    #expect(items.dropLast().allSatisfy { !$0.destructive })
    #expect(ActionCatalog.items(for: [Self.thought()]).first?.title == "Copy")
    #expect(ActionCatalog.items(for: [Self.thought(), screenshot]).first?.title == "Copy")
    #expect(ActionCatalog.items(for: []).isEmpty)
  }
}

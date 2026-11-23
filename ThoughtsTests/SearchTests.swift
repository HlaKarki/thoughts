import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct SearchTests {
  @Test func typingQueriesAfterAPauseAndClearingIsImmediate() async throws {
    let fixture = try ListFixture(searchDelay: .milliseconds(80))
    try fixture.addText("Ask the team for the staging API key", daysAgo: 2)
    try fixture.addText("Renew car registration", daysAgo: 1)
    try fixture.reload()
    fixture.model.query = "stag"
    #expect(fixture.model.matches == nil)
    try await Task.sleep(for: .milliseconds(30))
    fixture.model.query = "staging"
    try await Task.sleep(for: .milliseconds(60))
    #expect(fixture.model.matches == nil)
    try await Task.sleep(for: .milliseconds(150))
    #expect(fixture.model.visible.count == 1)
    fixture.model.query = ""
    #expect(fixture.model.matches == nil)
    #expect(fixture.model.visible.count == 2)
  }

  @Test func searchShowsClearedThoughts() async throws {
    let fixture = try ListFixture()
    try fixture.addText("Rotate the staging DB password", daysAgo: 3, done: true)
    _ = try fixture.store.clearDone()
    try fixture.reload()
    fixture.model.query = "staging"
    #expect(fixture.model.visible.count == 1)
    #expect(fixture.model.visible.first?.isCleared == true)
  }

  @Test func matchedWordsAreFoundAtWordStartsOnly() {
    let text = "Rotate the staging-db password for stagingUrl and restaging"
    let found = SearchHighlight.ranges(of: ["staging", "pass"], in: text).map { String(text[$0]) }
    #expect(found.sorted() == ["pass", "staging", "staging"])
    let marked = SearchHighlight.ranges(of: ["café"], in: "Cafe au lait")
    #expect(marked.count == 1)
  }

  @Test func sourceLineNamesTheAppAndWhereTheThoughtCame() {
    #expect(
      SearchHighlight.sourceLine(
        for: Source(app: "Safari", url: URL(string: "https://staging.acme.dev/projects")))
        == "Safari: staging.acme.dev/projects")
    #expect(
      SearchHighlight.sourceLine(for: Source(app: "Terminal", window: "ssh staging-db"))
        == "Terminal: ssh staging-db")
    #expect(SearchHighlight.sourceLine(for: Source(file: "/tmp/notes/report.pdf")) == "report.pdf")
    #expect(SearchHighlight.sourceLine(for: Source(app: "Slack")) == "Slack")
    #expect(SearchHighlight.sourceLine(for: nil) == nil)
  }
}

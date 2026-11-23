import Testing

@testable import ThoughtsCore

struct SourceRuleTests {
  static let own = "dev.example.thoughts"
  static let safari = AppSnapshot(pid: 10, bundleID: "com.apple.Safari", name: "Safari")
  static let notes = AppSnapshot(pid: 11, bundleID: "com.apple.Notes", name: "Notes")
  static let thoughts = AppSnapshot(pid: 12, bundleID: own, name: "Thoughts")
  static let shottr = AppSnapshot(pid: 13, bundleID: "cc.ffitch.shottr", name: "Shottr")

  @Test func frontmostAppIsTheSource() {
    let app = SourceRule.app(frontmost: Self.notes, history: [Self.safari], ownBundleID: Self.own)
    #expect(app == Self.notes)
  }

  @Test func ownPanelFallsBackToPreviousApp() {
    let app = SourceRule.app(
      frontmost: Self.thoughts, history: [Self.safari], ownBundleID: Self.own)
    #expect(app == Self.safari)
  }

  @Test func screenshotToolFallsBackToAppBeforeIt() {
    let app = SourceRule.app(
      frontmost: Self.shottr, history: [Self.safari, Self.shottr], ownBundleID: Self.own)
    #expect(app == Self.safari)
  }

  @Test func fallbackSkipsEveryUnusableAppAndPicksTheNewest() {
    let app = SourceRule.app(
      frontmost: Self.thoughts,
      history: [Self.safari, Self.notes, Self.shottr, Self.thoughts],
      ownBundleID: Self.own)
    #expect(app == Self.notes)
  }

  @Test func noUsableAppGivesNil() {
    #expect(SourceRule.app(frontmost: nil, history: [], ownBundleID: Self.own) == nil)
    let app = SourceRule.app(
      frontmost: Self.thoughts, history: [Self.shottr, Self.thoughts], ownBundleID: Self.own)
    #expect(app == nil)
  }
}

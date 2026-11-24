import Foundation
import Testing

@testable import ThoughtsCore

private let locale = Locale(identifier: "en_US")

private let calendar: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "America/New_York")!
  return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0)
  -> Date
{
  calendar.date(
    from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private let now = date(2026, 11, 22, 18, 30)

private func label(_ value: Date) -> String {
  RowTime.label(for: value, now: now, calendar: calendar, locale: locale)
}

private let folder = URL(fileURLWithPath: "/tmp/thoughts-format-tests/Thoughts")
private let store = ThoughtStore(folder: folder, trash: { $0 })

private func thought(_ name: String, _ content: ThoughtContent) -> Thought {
  Thought(
    id: ThoughtID(rawValue: name)!,
    created: now,
    content: content,
    file: folder.appendingPathComponent("\(name).md"),
    version: FileVersion(modified: now, size: 0)
  )
}

@Test func todayShowsTime() {
  #expect(label(date(2026, 11, 22, 18, 14)) == "6:14\u{202F}PM")
}

@Test func lastWeekShowsWeekday() {
  #expect(label(date(2026, 11, 17)) == "Tue")
}

@Test func sameYearShowsMonthDay() {
  #expect(label(date(2026, 11, 3)) == "Nov 3")
}

@Test func olderShowsYear() {
  #expect(label(date(2025, 11, 3)) == "Nov 3, 2025")
}

@Test func windowIsCalendarDaysNotHours() {
  #expect(label(date(2026, 11, 21, 23, 59)) == "Sat")
  #expect(label(date(2026, 11, 16, 0, 1)) == "Mon")
  #expect(label(date(2026, 11, 15, 23, 59)) == "Nov 15")
  #expect(label(date(2026, 11, 22, 0, 1)) == "12:01\u{202F}AM")
}

@Test func laterTimeOnSameDayShowsTime() {
  #expect(label(date(2026, 11, 22, 23, 0)) == "11:00\u{202F}PM")
}

@Test func laterDateOnAnotherDayShowsDate() {
  #expect(label(date(2026, 11, 25)) == "Nov 25")
  #expect(label(date(2027, 1, 5)) == "Jan 5, 2027")
}

@Test func labelUsesCalendarTimeZone() {
  var utc = calendar
  utc.timeZone = TimeZone(identifier: "UTC")!
  let value = date(2026, 11, 22, 23, 30)
  let shifted = RowTime.label(for: value, now: now, calendar: utc, locale: locale)
  #expect(shifted == "Nov 23")
  #expect(label(value) == "11:30\u{202F}PM")
}

@Test func markdownListMixesTextAndScreenshots() {
  let thoughts = [
    thought("aaaa1111", .text("first line\nsecond line\n\nfourth line")),
    thought("bbbb2222", .image(fileName: "bbbb2222.png", note: "")),
    thought("cccc3333", .image(fileName: "cccc3333.jpg", note: "a note")),
    thought("dddd4444", .text("single")),
  ]
  let expected = [
    "- first line",
    "  second line",
    "",
    "  fourth line",
    "- /tmp/thoughts-format-tests/Thoughts/bbbb2222.png",
    "- a note",
    "  /tmp/thoughts-format-tests/Thoughts/cccc3333.jpg",
    "- single",
  ].joined(separator: "\n")
  #expect(CopyFormat.markdownList(thoughts, store: store) == expected)
}

@Test func markdownListHasNoTrailingWhitespace() {
  let output = CopyFormat.markdownList(
    [thought("aaaa1111", .text("one\n\ntwo\n"))], store: store)
  #expect(output == "- one\n\n  two")
  #expect(
    CopyFormat.markdownList([thought("aaaa1111", .text("a\n   \nb"))], store: store)
      == "- a\n\n  b")
  #expect(
    CopyFormat.markdownList([thought("aaaa1111", .text("   \nfoo"))], store: store)
      == "-\n  foo")
  #expect(CopyFormat.markdownList([], store: store) == "")
}

@Test func markdownListUsesRawAbsolutePath() {
  let spaced = URL(fileURLWithPath: "/tmp/with space/Thoughts")
  let spacedStore = ThoughtStore(folder: spaced, trash: { $0 })
  let shot = Thought(
    id: ThoughtID(rawValue: "eeee5555")!,
    created: now,
    content: .image(fileName: "eeee5555.png", note: ""),
    file: spaced.appendingPathComponent("eeee5555.md"),
    version: FileVersion(modified: now, size: 0)
  )
  #expect(
    CopyFormat.markdownList([shot], store: spacedStore) == "- /tmp/with space/Thoughts/eeee5555.png"
  )
}

@Test func pathIsImageForScreenshotAndMarkdownForText() {
  let text = thought("aaaa1111", .text("hello"))
  let shot = thought("bbbb2222", .image(fileName: "bbbb2222.png", note: "n"))
  #expect(CopyFormat.path(of: text, store: store) == text.file)
  #expect(
    CopyFormat.path(of: shot, store: store)
      == folder.appendingPathComponent("bbbb2222.png"))
}

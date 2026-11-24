import Foundation
import Testing

@testable import ThoughtsCore

private let file = URL(fileURLWithPath: "/tmp/thoughts-tests/2026-11-22-181403-a1b2c3d4.md")
private let version = FileVersion(modified: Date(timeIntervalSince1970: 1_795_000_100), size: 120)
private let created = Date(timeIntervalSince1970: 1_795_000_000.12)
private let fallback = Date(timeIntervalSince1970: 1_700_000_000)

private func makeThought(
  id: String = "a1b2c3d4",
  done: Date? = nil,
  cleared: Bool = false,
  content: ThoughtContent = .text("remember the milk"),
  source: Source? = nil,
  extraFrontMatter: String = ""
) -> Thought {
  Thought(
    id: ThoughtID(rawValue: id)!,
    created: created,
    done: done,
    cleared: cleared,
    content: content,
    source: source,
    extraFrontMatter: extraFrontMatter,
    file: file,
    version: version
  )
}

private func decode(_ text: String) -> ThoughtEntry {
  FrontMatterCodec.decode(text, file: file, version: version, fallbackCreated: fallback)
}

@Test func roundTripsTextThought() {
  let thought = makeThought(done: Date(timeIntervalSince1970: 1_795_000_500.5), cleared: true)
  #expect(decode(FrontMatterCodec.encode(thought)) == .thought(thought))
}

@Test func roundTripsImageThoughtWithNoteAndSource() {
  let source = Source(
    app: "Safari",
    bundleID: "com.apple.Safari",
    window: "Docs",
    url: URL(string: "https://example.com/a?b=1#c"),
    title: "An example page",
    file: "notes.md"
  )
  let thought = makeThought(
    content: .image(fileName: "a1b2c3d4.png", note: "the chart\nwith two lines"),
    source: source
  )
  #expect(decode(FrontMatterCodec.encode(thought)) == .thought(thought))
}

@Test func keepsBodyStartingWithDashes() {
  let thought = makeThought(content: .text("---\nnot front matter"))
  #expect(decode(FrontMatterCodec.encode(thought)) == .thought(thought))
}

@Test func quotesYAMLSpecialCharacters() {
  let source = Source(
    app: "true",
    bundleID: "123",
    window: "Fix: #12 \"crash\"",
    title: "- [a]: {b} 'c' | > & * ! % @ `",
    file: "null"
  )
  let thought = makeThought(source: source)
  #expect(decode(FrontMatterCodec.encode(thought)) == .thought(thought))
}

@Test func keepsEmojiAndReadsCRLF() {
  let thought = makeThought(
    content: .text("ship it 🚀 日本語\nsecond line"),
    source: Source(window: "Mail 📬")
  )
  let lf = FrontMatterCodec.encode(thought)
  let crlf = lf.replacingOccurrences(of: "\n", with: "\r\n")
  #expect(decode(lf) == .thought(thought))
  #expect(decode(crlf) == decode(lf))
}

@Test func fileWithoutFrontMatterIsTextThought() {
  let plain = file.deletingLastPathComponent().appendingPathComponent("grocery list.md")
  let entry = FrontMatterCodec.decode(
    "milk\neggs\n", file: plain, version: version, fallbackCreated: fallback)
  let expected = Thought(
    id: ThoughtID(rawValue: "grocery list")!,
    created: fallback,
    content: .text("milk\neggs"),
    file: plain,
    version: version
  )
  #expect(entry == .thought(expected))
}

@Test func unparsableFrontMatterIsMalformed() {
  guard case .malformed(let url, let reason) = decode("---\nid: [\n---\n") else {
    Issue.record("expected malformed")
    return
  }
  #expect(url == file)
  #expect(!reason.isEmpty)
}

@Test func wrongTypeIsMalformed() {
  guard case .malformed(_, let reason) = decode("---\ncleared: maybe\n---\nbody\n") else {
    Issue.record("expected malformed")
    return
  }
  #expect(!reason.isEmpty)
}

@Test func keepsUnknownKeys() {
  let text = """
    ---
    id: a1b2c3d4
    tags: [a, b]
    created: 2026-11-22T18:14:03.120-05:00
    extra:
      owner: hla
      links:
        - one
        - two
    cleared: false
    ---
    body

    """
  guard case .thought(let first) = decode(text) else {
    Issue.record("expected thought")
    return
  }
  #expect(first.extraFrontMatter.contains("tags"))
  #expect(first.extraFrontMatter.contains("extra"))
  guard case .thought(let second) = decode(FrontMatterCodec.encode(first)) else {
    Issue.record("expected thought")
    return
  }
  #expect(second == first)
  let encoded = FrontMatterCodec.encode(second)
  let tags = encoded.range(of: "tags:")
  let extra = encoded.range(of: "extra:")
  #expect(tags != nil && extra != nil && tags!.lowerBound < extra!.lowerBound)
  #expect(encoded.contains("owner: hla"))
  #expect(encoded.contains("- two"))
}

@Test func missingKeysFallBack() {
  let text = "---\ncreated: 2026-11-22T18:14:03.120-05:00\n---\nhello\n"
  let entry = FrontMatterCodec.decode(
    text, file: file, version: version, fallbackCreated: fallback)
  guard case .thought(let thought) = entry else {
    Issue.record("expected thought")
    return
  }
  #expect(thought.id == ThoughtID(rawValue: "2026-11-22-181403-a1b2c3d4"))
  #expect(thought.done == nil)
  #expect(thought.cleared == false)
  #expect(thought.content == .text("hello"))
}

@Test func missingCreatedFallsBack() {
  guard case .thought(let thought) = decode("---\nid: x1\n---\nhello\n") else {
    Issue.record("expected thought")
    return
  }
  #expect(thought.created == fallback)
}

@Test func bodyKeepsTrailingNewlines() {
  let thought = makeThought(content: .text("line\n\n"))
  let encoded = FrontMatterCodec.encode(thought)
  #expect(encoded.hasSuffix("line\n\n\n"))
  #expect(decode(encoded) == .thought(thought))
}

@Test func writesMillisecondsAndOffset() {
  let zone = TimeZone(secondsFromGMT: -5 * 3600)!
  #expect(
    FrontMatterCodec.format(Date(timeIntervalSince1970: 1_795_000_000.12), in: zone)
      == "2026-11-18T06:06:40.120-05:00")
  #expect(
    FrontMatterCodec.format(
      Date(timeIntervalSince1970: 1_795_000_000), in: TimeZone(identifier: "UTC")!)
      == "2026-11-18T11:06:40.000Z")
}

@Test func randomIDsAreEightCrockfordCharacters() {
  let allowed = Set("0123456789abcdefghjkmnpqrstvwxyz")
  for _ in 0..<50 {
    let id = ThoughtID.random().rawValue
    #expect(id.count == 8)
    #expect(id.allSatisfy(allowed.contains))
  }
  #expect(ThoughtID(rawValue: "") == nil)
  #expect(ThoughtID(rawValue: "a/b") == nil)
}

private func thought(from text: String) -> Thought? {
  guard case .thought(let thought) = decode(text) else { return nil }
  return thought
}

@Test func plainNullImageIsAbsent() {
  let result = thought(from: "---\nimage: null\n---\nx\n")
  #expect(result?.content == .text("x"))
}

@Test func plainNullSourceFieldsAreAbsent() {
  let result = thought(from: "---\nsource: {window: null, url: ~, app: Code}\n---\nx\n")
  #expect(result?.source == Source(app: "Code"))
  let empty = thought(from: "---\nsource: {window: null, url: ~}\n---\nx\n")
  #expect(empty?.source == nil)
}

@Test func quotedNullStaysText() {
  let result = thought(from: "---\nsource: {window: 'null'}\n---\nx\n")
  #expect(result?.source?.window == "null")
}

@Test func imageWithPathIsMalformed() {
  for name in ["../../Documents/taxes.pdf", "sub/a.png", "/etc/passwd", ".", ".."] {
    guard case .malformed(_, let reason) = decode("---\nimage: \(name)\n---\nx\n") else {
      Issue.record("expected malformed for \(name)")
      continue
    }
    #expect(!reason.isEmpty)
  }
  #expect(
    thought(from: "---\nimage: shot.png\n---\nx\n")?.content
      == .image(fileName: "shot.png", note: "x"))
}

@Test func readsYAMLTimestampForms() {
  let expected = Date(timeIntervalSince1970: 1_795_389_243.12)
  let forms = [
    "2026-11-22T18:14:03.120-05:00",
    "2026-11-22 18:14:03.120000-05:00",
    "2026-11-22t18:14:03.12 -05:00",
    "2026-11-22 18:14:03.12 -5",
    "2026-11-22T23:14:03.120Z",
    "2026-11-22 23:14:03.12 Z",
    "2026-11-22 18:14:03.120-0500",
  ]
  for form in forms {
    #expect(FrontMatterCodec.parseDate(form) == expected, "\(form)")
  }
  #expect(
    FrontMatterCodec.parseDate("2026-11-22 23:14:03") == Date(timeIntervalSince1970: 1_795_389_243))
  #expect(
    thought(from: "---\ncreated: 2026-11-22 18:14:03.120000-05:00\n---\nx\n")?.created == expected)
  #expect(FrontMatterCodec.parseDate("2026-13-22T18:14:03Z") == nil)
  #expect(FrontMatterCodec.parseDate("yesterday") == nil)
}

@Test func canonicalMatchesWhatTheCodecWritesAndReads() {
  let raw = Date(timeIntervalSince1970: 1_795_389_243.1237)
  let canonical = FrontMatterCodec.canonical(raw)
  #expect(canonical == Date(timeIntervalSince1970: 1_795_389_243.124))
  #expect(FrontMatterCodec.canonical(canonical) == canonical)
  let zone = TimeZone(secondsFromGMT: 3600)!
  #expect(FrontMatterCodec.parseDate(FrontMatterCodec.format(raw, in: zone)) == canonical)
}

@Test func numericLookingIdsAreQuoted() {
  for id in ["1e234567", "0x12ab34", "12345678", "2026-11-22"] {
    let original = makeThought(id: id)
    let encoded = FrontMatterCodec.encode(original)
    #expect(encoded.contains("id: '\(id)'"), "\(id)")
    #expect(decode(encoded) == .thought(original))
  }
}

@Test func keepsUnknownSourceKeys() {
  let text = "---\nsource: {app: Code, line: 12, extra: {a: 1}}\n---\nx\n"
  guard let first = thought(from: text) else {
    Issue.record("expected thought")
    return
  }
  #expect(first.source == Source(app: "Code"))
  let encoded = FrontMatterCodec.encode(first)
  #expect(encoded.contains("line: 12"))
  #expect(thought(from: encoded) == first)
}

@Test func sourceWithOnlyUnknownKeysSurvives() {
  guard let first = thought(from: "---\nsource: {line: 12}\n---\nx\n") else {
    Issue.record("expected thought")
    return
  }
  #expect(first.source == nil)
  #expect(first.extraSource.contains("line: 12"))
  let again = thought(from: FrontMatterCodec.encode(first))
  #expect(again == first)
  #expect(FrontMatterCodec.encode(first).contains("source:\n  line: 12"))
}

@Test func duplicateKeysAreMalformed() {
  guard case .malformed(_, let reason) = decode("---\ncleared: true\ncleared: false\n---\nx\n")
  else {
    Issue.record("expected malformed")
    return
  }
  #expect(!reason.isEmpty)
}

@Test func anOpeningLineWithTrailingSpacesStartsFrontMatter() {
  for opening in ["--- ", "---\t", "---  \t"] {
    let text =
      "\(opening)\nid: a1b2c3d4\ncreated: 2026-11-22T18:14:03.120-05:00\ncleared: true\n---\nbody\n"
    guard let decoded = thought(from: text) else {
      Issue.record("expected thought")
      continue
    }
    #expect(decoded.cleared)
    #expect(decoded.content == .text("body"))
    #expect(decoded.id.rawValue == "a1b2c3d4")
    let encoded = FrontMatterCodec.encode(decoded)
    #expect(encoded.components(separatedBy: "id: ").count == 2)
    #expect(thought(from: encoded) == decoded)
  }
}

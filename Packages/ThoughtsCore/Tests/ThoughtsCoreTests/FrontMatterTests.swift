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

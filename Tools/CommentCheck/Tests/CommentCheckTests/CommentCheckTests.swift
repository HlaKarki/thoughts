import Foundation
import Testing

@testable import comment_check

struct CommentCheckTests {
  @Test func flagsLineComment() {
    let hits = CommentChecker.hits(path: "a.swift", contents: "let a = 1 // x")
    #expect(hits == [Hit(path: "a.swift", line: 1)])
  }

  @Test func flagsDocComment() {
    let hits = CommentChecker.hits(path: "a.swift", contents: "/// x\nfunc f() {}")
    #expect(hits == [Hit(path: "a.swift", line: 1)])
  }

  @Test func ignoresSlashesInStrings() {
    let hits = CommentChecker.hits(path: "a.swift", contents: "let u = \"http://a\"")
    #expect(hits.isEmpty)
  }

  @Test func ignoresRawAndMultilineStrings() {
    let raw = CommentChecker.hits(path: "a.swift", contents: "let a = #\"// no\"#")
    let multiline = CommentChecker.hits(path: "a.swift", contents: "let a = \"\"\"\n// no\n\"\"\"")
    #expect(raw.isEmpty)
    #expect(multiline.isEmpty)
  }

  @Test func flagsYAMLHashLine() {
    let hits = CommentChecker.hits(path: "ci.yml", contents: "name: a\n  # x\n")
    #expect(hits == [Hit(path: "ci.yml", line: 2)])
  }

  @Test func flagsTrailingYAMLComment() {
    let hits = CommentChecker.hits(path: "ci.yml", contents: "run: swift test  # x")
    #expect(hits == [Hit(path: "ci.yml", line: 1)])
  }

  @Test func ignoresHashInURLAndQuotes() {
    let url = CommentChecker.hits(path: "ci.yml", contents: "url: https://a/#b")
    let quoted = CommentChecker.hits(path: "run.sh", contents: "echo \"#\"")
    #expect(url.isEmpty)
    #expect(quoted.isEmpty)
  }

  @Test func allowsShebang() {
    let hits = CommentChecker.hits(path: "scripts/release", contents: "#!/bin/zsh\necho")
    #expect(hits.isEmpty)
  }

  @Test func flagsMarkupComments() {
    let markdown = CommentChecker.hits(path: "README.md", contents: "<!-- x -->")
    let css = CommentChecker.hits(path: "site.css", contents: "/* x */")
    #expect(markdown == [Hit(path: "README.md", line: 1)])
    #expect(css == [Hit(path: "site.css", line: 1)])
  }

  @Test func flagsSlashCommentsInConfigFiles() {
    let xcconfig = CommentChecker.hits(path: "Base.xcconfig", contents: "A = 1\n// x")
    let jsonc = CommentChecker.hits(path: "wrangler.jsonc", contents: "{\"a\": \"//b\", /* x */}")
    #expect(xcconfig == [Hit(path: "Base.xcconfig", line: 2)])
    #expect(jsonc == [Hit(path: "wrangler.jsonc", line: 1)])
  }

  @Test func allowsToolsVersionLineOnly() {
    let line = "// swift-tools-version: 6.2"
    let allowed = CommentChecker.hits(
      path: "Packages/A/Package.swift", contents: line + "\nlet a = 1")
    let lateLine = CommentChecker.hits(path: "Package.swift", contents: "\n" + line)
    let otherFile = CommentChecker.hits(path: "Other.swift", contents: line)
    #expect(allowed.isEmpty)
    #expect(lateLine == [Hit(path: "Package.swift", line: 2)])
    #expect(otherFile == [Hit(path: "Other.swift", line: 1)])
  }

  @Test func checksUntrackedFiles() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("comment-check-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Git.run(["init", "-q"], in: root)
    try "let a = 1 // x".write(
      to: root.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)
    let hits = try CommentChecker.check(root: root)
    #expect(hits == [Hit(path: "a.swift", line: 1)])
  }
}

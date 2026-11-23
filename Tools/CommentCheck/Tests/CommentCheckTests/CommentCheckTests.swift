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

  @Test func flagsCommentsInExampleXcconfig() {
    let hits = CommentChecker.hits(path: "Config/Local.xcconfig.example", contents: "A = 1\n// x")
    #expect(hits == [Hit(path: "Config/Local.xcconfig.example", line: 2)])
  }

  @Test func flagsHashLinesInGitIgnoreFiles() {
    let ignore = CommentChecker.hits(path: ".gitignore", contents: "build/\n# x")
    let attributes = CommentChecker.hits(path: "sub/.gitattributes", contents: "# x\n*.png binary")
    #expect(ignore == [Hit(path: ".gitignore", line: 2)])
    #expect(attributes == [Hit(path: "sub/.gitattributes", line: 1)])
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

  @Test func flagsScriptComments() {
    let line = CommentChecker.hits(path: "a.ts", contents: "const a = 1\nconst b = 2 // x")
    let block = CommentChecker.hits(path: "a.mjs", contents: "/* x */\nexport {}")
    let doc = CommentChecker.hits(path: "a.js", contents: "/**\n * x\n */\nf()")
    #expect(line == [Hit(path: "a.ts", line: 2)])
    #expect(block == [Hit(path: "a.mjs", line: 1)])
    #expect(doc == [Hit(path: "a.js", line: 1)])
  }

  @Test func ignoresSlashesInScriptStrings() {
    let quoted = CommentChecker.hits(path: "a.ts", contents: "const u = 'http://a' + \"/* b */\"")
    let escaped = CommentChecker.hits(path: "a.ts", contents: "const q = 'it\\'s // fine'")
    #expect(quoted.isEmpty)
    #expect(escaped.isEmpty)
  }

  @Test func ignoresSlashesInTemplateLiterals() {
    let plain = CommentChecker.hits(path: "a.ts", contents: "const u = `http://a\n/* b */`")
    let nested = CommentChecker.hits(
      path: "a.ts", contents: "const u = `${b ? `//c` : '/*d*/'}//e`\nconst f = 1 // x")
    #expect(plain.isEmpty)
    #expect(nested == [Hit(path: "a.ts", line: 2)])
  }

  @Test func flagsCommentsInsideTemplateExpressions() {
    let hits = CommentChecker.hits(path: "a.ts", contents: "const u = `${a /* x */}`")
    #expect(hits == [Hit(path: "a.ts", line: 1)])
  }

  @Test func ignoresSlashesInRegexLiterals() {
    let regex = CommentChecker.hits(path: "a.js", contents: "const r = /\\/\\/[/*]+/g.test(s)")
    let division = CommentChecker.hits(path: "a.js", contents: "const h = a / b / c")
    let returned = CommentChecker.hits(
      path: "a.js", contents: "function f() { return /\\/\\//.source }")
    #expect(regex.isEmpty)
    #expect(division.isEmpty)
    #expect(returned.isEmpty)
  }

  @Test func flagsJSXComments() {
    let child = CommentChecker.hits(
      path: "a.tsx", contents: "const a = (\n  <div>\n    {/* x */}\n  </div>\n)")
    let attribute = CommentChecker.hits(
      path: "a.tsx", contents: "const a = <div\n  // x\n  id=\"b\" />")
    #expect(child == [Hit(path: "a.tsx", line: 3)])
    #expect(attribute == [Hit(path: "a.tsx", line: 2)])
  }

  @Test func ignoresSlashesInJSXText() {
    let hits = CommentChecker.hits(
      path: "a.tsx",
      contents:
        "const a = <p>Go to https://a/b, it's /* fine */ <a href=\"//c\">{d}</a></p>\nconst e = <>{f}</>"
    )
    #expect(hits.isEmpty)
  }

  @Test func readsGenericsAsTypesInTSX() {
    let hits = CommentChecker.hits(
      path: "a.tsx", contents: "const [a, b] = useState<string>('//')\nconst c = d < e // x")
    #expect(hits == [Hit(path: "a.tsx", line: 2)])
  }

  @Test func skipsIgnoredScriptFiles() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("comment-check-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Git.run(["init", "-q"], in: root)
    try "gen.ts\n".write(
      to: root.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
    try "// generated".write(
      to: root.appendingPathComponent("gen.ts"), atomically: true, encoding: .utf8)
    try "const a = 1 // x".write(
      to: root.appendingPathComponent("a.ts"), atomically: true, encoding: .utf8)
    let hits = try CommentChecker.check(root: root)
    #expect(hits == [Hit(path: "a.ts", line: 1)])
  }

  @Test func readsTypeLevelGenericsInTSX() {
    let alias = CommentChecker.hits(
      path: "a.tsx", contents: "type F = <T>(x: T) => T\nconst a = 1 // x")
    let annotation = CommentChecker.hits(
      path: "a.tsx", contents: "let f: <T>(x: T) => T\nconst g = <T,>(x: T) => x // x")
    #expect(alias == [Hit(path: "a.tsx", line: 2)])
    #expect(annotation == [Hit(path: "a.tsx", line: 2)])
  }

  @Test func readsDivisionAfterPostfixOperators() {
    let increment = CommentChecker.hits(path: "a.ts", contents: "const c = a++ / b // x")
    let assertion = CommentChecker.hits(path: "a.ts", contents: "const d = a! / b // x")
    let parenthesis = CommentChecker.hits(path: "a.ts", contents: "const e = (a) / b // x")
    #expect(increment == [Hit(path: "a.ts", line: 1)])
    #expect(assertion == [Hit(path: "a.ts", line: 1)])
    #expect(parenthesis == [Hit(path: "a.ts", line: 1)])
  }

  @Test func skipsScriptShebang() {
    let hits = CommentChecker.hits(
      path: "run.mjs", contents: "#!/usr/bin/env bun\nconst a = 1 // x")
    #expect(hits == [Hit(path: "run.mjs", line: 2)])
  }

  @Test func reportsUnclosedElementAsUnparsed() {
    let hits = CommentChecker.hits(path: "a.tsx", contents: "const a = <div>\nconst b = 1")
    #expect(hits == [Hit(path: "a.tsx", line: 1, kind: .unparsed)])
  }

  @Test func reportsUnclosedRegexAndTemplateAsUnparsed() {
    let regex = CommentChecker.hits(path: "a.js", contents: "const r = /abc\nconst b = 1")
    let template = CommentChecker.hits(path: "a.ts", contents: "const a = 1\nconst t = `abc")
    #expect(regex == [Hit(path: "a.js", line: 1, kind: .unparsed)])
    #expect(template == [Hit(path: "a.ts", line: 2, kind: .unparsed)])
  }

  @Test func failsTheCheckOnUnparsedFiles() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("comment-check-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Git.run(["init", "-q"], in: root)
    try "const a = <div>\n".write(
      to: root.appendingPathComponent("a.tsx"), atomically: true, encoding: .utf8)
    let hits = try CommentChecker.check(root: root)
    #expect(hits == [Hit(path: "a.tsx", line: 1, kind: .unparsed)])
  }
}

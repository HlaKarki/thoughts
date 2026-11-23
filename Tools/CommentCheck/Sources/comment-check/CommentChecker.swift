import Foundation

enum CommentChecker {
  private static let toolsVersionPrefix = "// swift-tools-version:"

  static func hits(path: String, contents: String) -> [Hit] {
    lines(path: path, contents: contents).map { Hit(path: path, line: $0) }
  }

  static func check(root: URL) throws -> [Hit] {
    var hits: [Hit] = []
    for path in try Git.listedFiles(in: root) {
      let url = root.appendingPathComponent(path)
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
        !isDirectory.boolValue,
        let data = try? Data(contentsOf: url),
        let contents = String(data: data, encoding: .utf8)
      else { continue }
      hits += Self.hits(path: path, contents: contents)
    }
    return hits
  }

  private static func lines(path: String, contents: String) -> [Int] {
    let routed = path.hasSuffix(".example") ? String(path.dropLast(".example".count)) : path
    let name = (routed as NSString).lastPathComponent
    let ext = (routed as NSString).pathExtension
    if name == ".gitignore" || name == ".gitattributes" {
      return TextComments.hashLines(in: contents)
    }
    switch ext {
    case "swift":
      let toolsVersionExempt = name == "Package.swift" && contents.hasPrefix(toolsVersionPrefix)
      return SwiftComments.lines(in: contents).filter { !(toolsVersionExempt && $0 == 1) }
    case "yml", "yaml", "sh", "rb":
      return TextComments.hashLines(in: contents)
    case "ts", "js", "mjs":
      return ScriptComments.lines(in: contents, jsx: false)
    case "tsx":
      return ScriptComments.lines(in: contents, jsx: true)
    case "xcconfig", "jsonc":
      return TextComments.slashLines(in: contents)
    case "html", "md", "plist", "entitlements":
      return TextComments.lines(containing: "<!--", in: contents)
    case "css":
      return TextComments.lines(containing: "/*", in: contents)
    default:
      let isScript = routed.hasPrefix("scripts/") || routed.contains("/scripts/")
      return isScript ? TextComments.hashLines(in: contents) : []
    }
  }
}

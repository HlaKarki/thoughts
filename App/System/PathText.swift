import Foundation

enum PathText {
  static func abbreviated(_ url: URL, home: URL) -> String {
    let path = url.standardized.path
    let root = home.standardized.path
    if path == root { return "~" }
    if path.hasPrefix(root + "/") { return "~" + path.dropFirst(root.count) }
    return path
  }
}

import Foundation

@main
struct Entry {
  static func main() {
    let arguments = CommandLine.arguments.dropFirst()
    guard let root = arguments.first, arguments.count == 1 else {
      FileHandle.standardError.write(Data("usage: comment-check <root>\n".utf8))
      exit(2)
    }
    do {
      let hits = try CommentChecker.check(root: URL(fileURLWithPath: root))
      for hit in hits {
        print("\(hit.path):\(hit.line): comment")
      }
      exit(hits.isEmpty ? 0 : 1)
    } catch {
      FileHandle.standardError.write(Data("comment-check: \(error)\n".utf8))
      exit(2)
    }
  }
}

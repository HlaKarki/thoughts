import SwiftParser
import SwiftSyntax

enum SwiftComments {
  static func lines(in contents: String) -> [Int] {
    let tree = Parser.parse(source: contents)
    let converter = SourceLocationConverter(fileName: "", tree: tree)
    var lines: [Int] = []
    for token in tree.tokens(viewMode: .sourceAccurate) {
      let leading = token.position
      let trailing = token.endPositionBeforeTrailingTrivia
      for (start, trivia) in [(leading, token.leadingTrivia), (trailing, token.trailingTrivia)] {
        var offset = start.utf8Offset
        for piece in trivia {
          if piece.isComment {
            lines.append(converter.location(for: AbsolutePosition(utf8Offset: offset)).line)
          }
          offset += piece.sourceLength.utf8Length
        }
      }
    }
    return lines
  }
}

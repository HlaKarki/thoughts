import SwiftUI
import ThoughtsCore

enum SearchHighlight {
  static func terms(in query: String) -> [String] {
    query.split(whereSeparator: \.isWhitespace)
      .filter { $0.contains { $0.isLetter || $0.isNumber } }
      .map(String.init)
  }

  static func ranges(of terms: [String], in text: String) -> [Range<String.Index>] {
    var found: [Range<String.Index>] = []
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    for term in terms where !term.isEmpty {
      var cursor = text.startIndex
      while cursor < text.endIndex,
        let range = text.range(of: term, options: options, range: cursor..<text.endIndex)
      {
        let startsWord =
          range.lowerBound == text.startIndex
          || !text[text.index(before: range.lowerBound)].isWordCharacter
        if startsWord { found.append(range) }
        cursor = range.upperBound
      }
    }
    return found
  }

  static func attributed(_ text: String, terms: [String], size: CGFloat = 13) -> AttributedString {
    var result = AttributedString(text)
    for range in ranges(of: terms, in: text) {
      if let target = Range(range, in: result) {
        result[target].font = .system(size: size, weight: .semibold)
      }
    }
    return result
  }

  static func sourceLine(for source: Source?) -> String? {
    guard let source else { return nil }
    let detail = [
      source.window, source.title, Self.display(source.url), Self.fileName(source.file),
    ]
    .compactMap { $0 }
    .first { !$0.isEmpty }
    let app = source.app.flatMap { $0.isEmpty ? nil : $0 }
    switch (app, detail) {
    case (let app?, let detail?): return "\(app): \(detail)"
    case (let app?, nil): return app
    case (nil, let detail?): return detail
    case (nil, nil): return nil
    }
  }

  private static func display(_ url: URL?) -> String? {
    guard let url, let host = url.host else { return url?.absoluteString }
    let path = url.path == "/" ? "" : url.path
    return host + path
  }

  private static func fileName(_ path: String?) -> String? {
    guard let path, !path.isEmpty else { return nil }
    return (path as NSString).lastPathComponent
  }
}

extension Character {
  fileprivate var isWordCharacter: Bool { isLetter || isNumber }
}

struct ClearedTag: View {
  var body: some View {
    Text("Cleared")
      .font(.system(size: 10, weight: .medium))
      .foregroundStyle(Color(nsColor: .secondaryLabelColor))
      .padding(.horizontal, 6)
      .frame(height: 16)
      .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
  }
}

struct SourceLine: View {
  let thought: Thought
  let terms: [String]

  var body: some View {
    let source = SearchHighlight.sourceLine(for: thought.source)
    if thought.cleared || source != nil {
      HStack(spacing: 6) {
        if thought.cleared { ClearedTag() }
        if let source {
          Text(SearchHighlight.attributed(source, terms: terms, size: 11))
            .font(.system(size: 11))
            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
      .frame(minHeight: 16, alignment: .leading)
    }
  }
}

struct ImageTextLine: View {
  let excerpt: String
  let terms: [String]

  var body: some View {
    (Text("Text in image") + Text(verbatim: ": \"")
      + Text(SearchHighlight.attributed(excerpt, terms: terms, size: 11)) + Text(verbatim: "\""))
      .font(.system(size: 11))
      .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
      .lineLimit(1)
      .truncationMode(.tail)
      .frame(minHeight: 16, alignment: .leading)
  }
}

import Foundation

public enum CopyFormat {
  public static func markdownList(_ thoughts: [Thought], store: ThoughtStore) -> String {
    thoughts.flatMap { item(for: $0, store: store) }.joined(separator: "\n")
  }

  public static func path(of thought: Thought, store: ThoughtStore) -> URL {
    store.imageURL(of: thought) ?? thought.file
  }

  private static func item(for thought: Thought, store: ThoughtStore) -> [String] {
    switch thought.content {
    case .text(let text):
      return bullet(text)
    case .image(_, let note):
      let path = path(of: thought, store: store).path
      let trimmed = trimmed(note)
      guard !trimmed.isEmpty else { return ["- " + path] }
      return bullet(trimmed) + ["  " + path]
    }
  }

  private static func bullet(_ text: String) -> [String] {
    let lines = trimmed(text).components(separatedBy: .newlines)
    let first = lines[0].isEmpty ? "-" : "- " + lines[0]
    return [first] + lines.dropFirst().map { $0.isEmpty ? "" : "  " + $0 }
  }

  private static func trimmed(_ text: String) -> String {
    var value = Substring(text)
    while let last = value.last, last.isWhitespace { value = value.dropLast() }
    return String(value)
  }
}

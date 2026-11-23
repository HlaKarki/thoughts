import ArgumentParser
import Foundation
import ThoughtsCore

public func errorMessage(for error: Error) -> String {
  let message: String
  switch error {
  case ThoughtsError.notFound(let query):
    message = "No thought matches \"\(query)\""
  case ThoughtsError.ambiguous(let query, let ids):
    message =
      "\"\(query)\" matches \(ids.count) thoughts: \(ids.map(\.rawValue).joined(separator: ", "))"
  case ThoughtsError.storageUnavailable(let path):
    message = "The thoughts folder is not available at \(path)"
  case ThoughtsError.changedOnDisk(let id):
    message = "Thought \(id) changed on disk, try again"
  case ThoughtsError.deletedOnDisk(let id):
    message = "Thought \(id) was deleted"
  case ThoughtsError.folderNotEmpty(let names):
    message = "The folder is not empty: \(names.joined(separator: ", "))"
  case ThoughtsError.clipboardChanged:
    message = "The clipboard changed"
  case ThoughtsError.io(let text):
    message = text
  case let error as ValidationError:
    message = error.message
  default:
    message = error.localizedDescription
  }
  return message.split(whereSeparator: \.isNewline).joined(separator: " ")
}

enum Output {
  static func json<T: Encodable>(_ value: T, pretty: Bool = true) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    if pretty { encoder.outputFormatting.insert(.prettyPrinted) }
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }

  static func row(_ thought: Thought, now: Date = Date()) -> String {
    let time = RowTime.label(for: thought.created, now: now, calendar: .current, locale: .current)
    let summary: String
    switch thought.content {
    case .text(let text):
      summary = firstLine(of: text)
    case .image(_, let note):
      summary = "[image] " + firstLine(of: note)
    }
    return "\(thought.id.rawValue)  \(time)  \(summary)"
      .trimmingCharacters(in: .whitespaces)
  }

  static func detail(_ thought: Thought, store: ThoughtStore) -> String {
    var lines = ["id: \(thought.id.rawValue)"]
    lines.append("created: \(timestamp(thought.created))")
    if let done = thought.done { lines.append("done: \(timestamp(done))") }
    if let app = thought.source?.app { lines.append("source: \(app)") }
    if let url = thought.source?.url { lines.append("url: \(url.absoluteString)") }
    lines.append("file: \(thought.file.path)")
    let body: String
    switch thought.content {
    case .text(let text):
      body = text
    case .image(_, let note):
      if let image = store.imageURL(of: thought) { lines.append("image: \(image.path)") }
      body = note
    }
    lines.append("")
    lines.append(body)
    return lines.joined(separator: "\n")
  }

  private static func firstLine(of text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.components(separatedBy: .newlines).first ?? ""
  }

  private static func timestamp(_ date: Date) -> String {
    date.formatted(.iso8601)
  }
}

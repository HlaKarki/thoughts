import Foundation
import Yams

public enum FrontMatterCodec {
  private static let ownKeys: Set<String> = [
    "id", "created", "done", "cleared", "image", "source",
  ]
  private static let sourceKeys: Set<String> = [
    "app", "bundle", "window", "url", "title", "file",
  ]

  public static func encode(_ thought: Thought) -> String {
    var pairs: [(Node, Node)] = [
      (key("id"), string(thought.id.rawValue)),
      (key("created"), plain(format(thought.created, in: .current))),
      (key("done"), plain(thought.done.map { format($0, in: .current) } ?? "null")),
      (key("cleared"), plain(thought.cleared ? "true" : "false")),
    ]
    let body: String
    switch thought.content {
    case .text(let text):
      body = text
    case .image(let fileName, let note):
      pairs.append((key("image"), string(fileName)))
      body = note
    }
    if let node = sourceNode(thought.source, extra: thought.extraSource) {
      pairs.append((key("source"), node))
    }
    var yaml = emit(Node(pairs))
    yaml += thought.extraFrontMatter
    if !yaml.isEmpty, !yaml.hasSuffix("\n") { yaml += "\n" }
    return "---\n" + yaml + "---\n" + body + "\n"
  }

  public static func decode(
    _ text: String, file: URL, version: FileVersion, fallbackCreated: Date
  ) -> ThoughtEntry {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    let stem = file.deletingPathExtension().lastPathComponent

    guard normalized.hasPrefix("---\n") else {
      guard let id = ThoughtID(rawValue: stem) else {
        return .malformed(file: file, reason: "File name is not a valid thought id")
      }
      let thought = Thought(
        id: id,
        created: fallbackCreated,
        content: .text(stripTrailingNewline(normalized)),
        file: file,
        version: version
      )
      return .thought(thought)
    }

    guard let (yaml, body) = split(normalized) else {
      return .malformed(file: file, reason: "Front matter is not closed by a --- line")
    }

    let root: Node?
    do {
      root = try compose(yaml: yaml)
    } catch {
      return .malformed(file: file, reason: "Front matter is not valid YAML: \(error)")
    }
    var pairs: [(Node, Node)] = []
    if let root {
      guard case .mapping(let mapping) = root else {
        return .malformed(file: file, reason: "Front matter is not a mapping")
      }
      pairs = Array(mapping)
    }

    var values: [String: Node] = [:]
    var extra: [(Node, Node)] = []
    for (keyNode, valueNode) in pairs {
      if let name = keyNode.scalar?.string, ownKeys.contains(name) {
        values[name] = valueNode
      } else {
        extra.append((keyNode, valueNode))
      }
    }

    switch fields(values, stem: stem, fallbackCreated: fallbackCreated) {
    case .failure(let failure):
      return .malformed(file: file, reason: failure.reason)
    case .success(let fields):
      let note = stripTrailingNewline(body)
      let content: ThoughtContent =
        fields.image.map { .image(fileName: $0, note: note) } ?? .text(note)
      let thought = Thought(
        id: fields.id,
        created: fields.created,
        done: fields.done,
        cleared: fields.cleared,
        content: content,
        source: fields.source,
        extraFrontMatter: extra.isEmpty ? "" : emit(Node(extra)),
        extraSource: fields.extraSource,
        file: file,
        version: version
      )
      return .thought(thought)
    }
  }

  static func canonical(_ date: Date) -> Date {
    Date(timeIntervalSince1970: (date.timeIntervalSince1970 * 1000).rounded() / 1000)
  }

  static func format(_ date: Date, in zone: TimeZone) -> String {
    let milliseconds = Int((canonical(date).timeIntervalSince1970 * 1000).rounded())
    let seconds = Date(timeIntervalSince1970: Double(milliseconds.floorDivided(by: 1000)))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: seconds)
    let offset = zone.secondsFromGMT(for: seconds)
    let zoneText =
      offset == 0
      ? "Z"
      : String(
        format: "%@%02d:%02d", offset < 0 ? "-" : "+", abs(offset) / 3600, abs(offset) % 3600 / 60)
    return String(
      format: "%04d-%02d-%02dT%02d:%02d:%02d.%03d%@",
      c.year!, c.month!, c.day!, c.hour!, c.minute!, c.second!,
      milliseconds.floorModulo(1000), zoneText)
  }

  static func parseDate(_ text: String) -> Date? {
    let pattern =
      #"([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})(?:(?:[Tt]|[ \t]+)([0-9]{1,2}):([0-9]{2}):([0-9]{2})(?:\.([0-9]*))?(?:[ \t]*(?:(Z)|([-+])([0-9]{1,2})(?::?([0-9]{2}))?))?)?"#
    guard
      let regex = try? Regex(pattern),
      let match = try? regex.wholeMatch(in: text.trimmingCharacters(in: .whitespaces))
    else { return nil }

    func group(_ index: Int) -> String? { match.output[index].substring.map(String.init) }
    func number(_ index: Int) -> Int { group(index).flatMap(Int.init) ?? 0 }

    var offset = 0
    if let sign = group(9) {
      let hours = number(10)
      let minutes = number(11)
      guard hours <= 23, minutes <= 59 else { return nil }
      offset = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
    }
    guard let zone = TimeZone(secondsFromGMT: offset) else { return nil }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let components = DateComponents(
      year: number(1), month: number(2), day: number(3),
      hour: number(4), minute: number(5), second: number(6))
    guard
      let whole = calendar.date(from: components),
      calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: whole)
        == components
    else { return nil }

    let fraction = group(7).flatMap { $0.isEmpty ? nil : Double("0." + $0) } ?? 0
    return canonical(whole.addingTimeInterval(fraction))
  }
}

private struct Failure: Error {
  let reason: String
}

private struct Fields {
  var id: ThoughtID
  var created: Date
  var done: Date?
  var cleared: Bool
  var image: String?
  var source: Source?
  var extraSource: String
}

extension FrontMatterCodec {
  fileprivate static func fields(
    _ values: [String: Node], stem: String, fallbackCreated: Date
  ) -> Result<Fields, Failure> {
    do {
      let id: ThoughtID
      if let node = values["id"] {
        guard let raw = node.scalar?.string, let parsed = ThoughtID(rawValue: raw) else {
          throw Failure(reason: "id is not a valid thought id")
        }
        id = parsed
      } else {
        guard let parsed = ThoughtID(rawValue: stem) else {
          throw Failure(reason: "File name is not a valid thought id")
        }
        id = parsed
      }

      var created = fallbackCreated
      if let node = values["created"] {
        guard let raw = node.scalar?.string, let date = parseDate(raw) else {
          throw Failure(reason: "created is not an ISO 8601 date")
        }
        created = date
      }

      var done: Date?
      if let node = values["done"], !isNull(node) {
        guard let raw = node.scalar?.string, let date = parseDate(raw) else {
          throw Failure(reason: "done is not an ISO 8601 date or null")
        }
        done = date
      }

      var cleared = false
      if let node = values["cleared"] {
        guard let flag = node.bool else { throw Failure(reason: "cleared is not true or false") }
        cleared = flag
      }

      var image: String?
      if let node = values["image"], !isNull(node) {
        guard let name = node.scalar?.string, isFileName(name) else {
          throw Failure(reason: "image is not a plain file name")
        }
        image = name
      }

      var source: Source?
      var extraSource = ""
      if let node = values["source"] {
        (source, extraSource) = try sourceValue(node)
      }

      return .success(
        Fields(
          id: id, created: created, done: done, cleared: cleared, image: image, source: source,
          extraSource: extraSource)
      )
    } catch let failure as Failure {
      return .failure(failure)
    } catch {
      return .failure(Failure(reason: "\(error)"))
    }
  }

  fileprivate static func sourceValue(_ node: Node) throws -> (Source?, String) {
    if isNull(node) { return (nil, "") }
    guard case .mapping(let mapping) = node else {
      throw Failure(reason: "source is not a mapping")
    }
    var source = Source()
    var extra: [(Node, Node)] = []
    for (keyNode, valueNode) in mapping {
      guard let name = keyNode.scalar?.string, sourceKeys.contains(name) else {
        extra.append((keyNode, valueNode))
        continue
      }
      if isNull(valueNode) { continue }
      guard let value = valueNode.scalar?.string else {
        throw Failure(reason: "source.\(name) is not text")
      }
      switch name {
      case "app": source.app = value
      case "bundle": source.bundleID = value
      case "window": source.window = value
      case "title": source.title = value
      case "file": source.file = value
      default:
        guard let url = URL(string: value) else {
          throw Failure(reason: "source.url is not a URL")
        }
        source.url = url
      }
    }
    return (source == Source() ? nil : source, extra.isEmpty ? "" : emit(Node(extra)))
  }

  fileprivate static func sourceNode(_ source: Source?, extra: String) -> Node? {
    var pairs: [(Node, Node)] = []
    func add(_ name: String, _ value: String?) {
      if let value { pairs.append((key(name), string(value))) }
    }
    add("app", source?.app)
    add("bundle", source?.bundleID)
    add("window", source?.window)
    add("url", source?.url?.absoluteString)
    add("title", source?.title)
    add("file", source?.file)
    if case .mapping(let mapping)? = try? compose(yaml: extra) {
      pairs.append(contentsOf: Array(mapping))
    }
    return pairs.isEmpty ? nil : Node(pairs)
  }

  fileprivate static func isNull(_ node: Node) -> Bool {
    node.scalar.flatMap(NSNull.construct) != nil
  }

  fileprivate static func isFileName(_ name: String) -> Bool {
    !name.isEmpty && name != "." && name != ".." && !name.contains("/")
  }

  fileprivate static func split(_ text: String) -> (yaml: String, body: String)? {
    let rest = text.dropFirst(4)
    if rest.hasPrefix("---\n") { return ("", String(rest.dropFirst(4))) }
    if rest == "---" { return ("", "") }
    if let range = rest.range(of: "\n---\n") {
      return (String(rest[..<range.lowerBound]) + "\n", String(rest[range.upperBound...]))
    }
    if rest.hasSuffix("\n---") {
      return (String(rest.dropLast(3)), "")
    }
    return nil
  }

  fileprivate static func stripTrailingNewline(_ text: String) -> String {
    text.hasSuffix("\n") ? String(text.dropLast()) : text
  }

  fileprivate static func key(_ name: String) -> Node { Node(name) }

  fileprivate static func plain(_ text: String) -> Node { Node(text) }

  fileprivate static func string(_ text: String) -> Node { .scalar(text.represented()) }

  fileprivate static func emit(_ node: Node) -> String {
    do {
      return try serialize(node: node, width: -1, allowUnicode: true)
    } catch {
      preconditionFailure("Front matter could not be serialized: \(error)")
    }
  }
}

extension Int {
  fileprivate func floorDivided(by divisor: Int) -> Int {
    let quotient = self / divisor
    return self % divisor < 0 ? quotient - 1 : quotient
  }

  fileprivate func floorModulo(_ divisor: Int) -> Int {
    let remainder = self % divisor
    return remainder < 0 ? remainder + divisor : remainder
  }
}

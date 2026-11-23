enum TextComments {
  static func hashLines(in contents: String) -> [Int] {
    var lines: [Int] = []
    for (index, line) in contents.split(separator: "\n", omittingEmptySubsequences: false)
      .enumerated()
    {
      if index == 0 && line.hasPrefix("#!") { continue }
      if hasHashComment(line) { lines.append(index + 1) }
    }
    return lines
  }

  static func slashLines(in contents: String) -> [Int] {
    var lines: [Int] = []
    for (index, line) in contents.split(separator: "\n", omittingEmptySubsequences: false)
      .enumerated()
    {
      if hasSlashComment(line) { lines.append(index + 1) }
    }
    return lines
  }

  static func lines(containing marker: String, in contents: String) -> [Int] {
    var lines: [Int] = []
    for (index, line) in contents.split(separator: "\n", omittingEmptySubsequences: false)
      .enumerated()
    {
      if line.contains(marker) { lines.append(index + 1) }
    }
    return lines
  }

  private static func hasHashComment(_ line: Substring) -> Bool {
    var quote: Character?
    var previous: Character?
    var escaped = false
    for character in line {
      defer { previous = character }
      if escaped {
        escaped = false
        continue
      }
      if let open = quote {
        if character == "\\" && open == "\"" {
          escaped = true
        } else if character == open {
          quote = nil
        }
      } else if character == "\"" || character == "'" {
        quote = character
      } else if character == "#" && (previous == nil || previous == " " || previous == "\t") {
        return true
      }
    }
    return false
  }

  private static func hasSlashComment(_ line: Substring) -> Bool {
    var inString = false
    var escaped = false
    var previous: Character?
    for character in line {
      defer { previous = character }
      if escaped {
        escaped = false
        continue
      }
      if inString {
        if character == "\\" {
          escaped = true
        } else if character == "\"" {
          inString = false
        }
      } else if character == "\"" {
        inString = true
      } else if previous == "/" && (character == "/" || character == "*") {
        return true
      }
    }
    return false
  }
}

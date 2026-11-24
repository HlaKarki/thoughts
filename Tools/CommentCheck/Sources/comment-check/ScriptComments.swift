enum ScriptComments {
  struct Result: Equatable {
    let lines: [Int]
    let unparsedLine: Int?
  }

  static func scan(_ contents: String, jsx: Bool) -> Result {
    var scanner = Scanner(bytes: Array(contents.utf8), jsx: jsx)
    scanner.skipShebang()
    scanner.scanCode(nested: false)
    return Result(lines: scanner.lines, unparsedLine: scanner.unparsedLine)
  }
}

private struct Scanner {
  let bytes: [UInt8]
  let jsx: Bool
  var index = 0
  var lines: [Int] = []
  var unparsedLine: Int?
  var expectsExpression = true

  init(bytes: [UInt8], jsx: Bool) {
    self.bytes = bytes
    self.jsx = jsx
  }

  private static let expressionKeywords: Set<String> = [
    "return", "typeof", "instanceof", "in", "of", "new", "delete", "void", "throw", "case", "do",
    "else", "yield", "await",
  ]

  private func peek(_ offset: Int = 0) -> UInt8? {
    let position = index + offset
    return position < bytes.count ? bytes[position] : nil
  }

  private func line(at position: Int) -> Int {
    var count = 1
    for byte in bytes[..<position] where byte == ascii("\n") {
      count += 1
    }
    return count
  }

  mutating func skipShebang() {
    guard peek() == ascii("#"), peek(1) == ascii("!") else { return }
    while let byte = peek(), byte != ascii("\n") {
      index += 1
    }
  }

  private mutating func markUnparsed(at position: Int) {
    if unparsedLine == nil {
      unparsedLine = line(at: position)
    }
  }

  @discardableResult
  mutating func scanCode(nested: Bool) -> Bool {
    let start = index
    var depth = 0
    while let byte = peek() {
      switch byte {
      case ascii(" "), ascii("\t"), ascii("\n"), ascii("\r"):
        index += 1
      case ascii("'"), ascii("\""):
        skipString(quote: byte)
        expectsExpression = false
      case ascii("`"):
        let opening = index
        if !skipTemplate() {
          markUnparsed(at: opening)
        }
        expectsExpression = false
      case ascii("/"):
        if peek(1) == ascii("/") {
          lines.append(line(at: index))
          skipLineComment()
        } else if peek(1) == ascii("*") {
          lines.append(line(at: index))
          skipBlockComment()
        } else if expectsExpression {
          let opening = index
          if !skipRegex() {
            markUnparsed(at: opening)
          }
          expectsExpression = false
        } else {
          index += 1
          expectsExpression = true
        }
      case ascii("<") where jsx && expectsExpression && startsElement():
        scanElementOrTypeParameters()
      case ascii("{"):
        depth += 1
        index += 1
        expectsExpression = true
      case ascii("}"):
        if nested && depth == 0 {
          index += 1
          return true
        }
        depth -= 1
        index += 1
        expectsExpression = true
      case ascii(")"), ascii("]"):
        index += 1
        expectsExpression = false
      case ascii("+"), ascii("-"):
        if !expectsExpression && peek(1) == byte {
          index += 2
        } else {
          index += 1
          expectsExpression = true
        }
      case ascii("!") where !expectsExpression && peek(1) != ascii("="):
        index += 1
      default:
        if isWordByte(byte) {
          let word = readWord()
          expectsExpression = Self.expressionKeywords.contains(word)
        } else {
          index += 1
          expectsExpression = true
        }
      }
    }
    if nested {
      markUnparsed(at: start)
    }
    return !nested
  }

  private func isWordByte(_ byte: UInt8) -> Bool {
    switch byte {
    case ascii("a")...ascii("z"), ascii("A")...ascii("Z"), ascii("0")...ascii("9"), ascii("_"),
      ascii("$"), 0x80...0xFF:
      return true
    default:
      return false
    }
  }

  private mutating func readWord() -> String {
    let start = index
    while let byte = peek(), isWordByte(byte) || byte == ascii(".") && isDigit(bytes[start]) {
      index += 1
    }
    return String(decoding: bytes[start..<index], as: UTF8.self)
  }

  private func isDigit(_ byte: UInt8) -> Bool {
    (ascii("0")...ascii("9")).contains(byte)
  }

  private mutating func skipLineComment() {
    while let byte = peek(), byte != ascii("\n") {
      index += 1
    }
  }

  private mutating func skipBlockComment() {
    index += 2
    while let byte = peek() {
      if byte == ascii("*") && peek(1) == ascii("/") {
        index += 2
        return
      }
      index += 1
    }
  }

  private mutating func skipString(quote: UInt8) {
    index += 1
    while let byte = peek() {
      index += 1
      if byte == ascii("\\") {
        index += 1
      } else if byte == quote || byte == ascii("\n") {
        return
      }
    }
  }

  private mutating func skipTemplate() -> Bool {
    index += 1
    while let byte = peek() {
      if byte == ascii("\\") {
        index += 2
      } else if byte == ascii("`") {
        index += 1
        return true
      } else if byte == ascii("$") && peek(1) == ascii("{") {
        index += 2
        expectsExpression = true
        guard scanCode(nested: true) else { return false }
      } else {
        index += 1
      }
    }
    return false
  }

  private mutating func skipRegex() -> Bool {
    index += 1
    var inClass = false
    var closed = false
    while let byte = peek(), byte != ascii("\n") {
      index += 1
      if byte == ascii("\\") {
        index += 1
      } else if byte == ascii("[") {
        inClass = true
      } else if byte == ascii("]") {
        inClass = false
      } else if byte == ascii("/") && !inClass {
        closed = true
        break
      }
    }
    while let byte = peek(), isWordByte(byte) {
      index += 1
    }
    return closed
  }

  private func startsElement() -> Bool {
    guard let next = peek(1) else { return false }
    return next == ascii(">") || (ascii("a")...ascii("z")).contains(next)
      || (ascii("A")...ascii("Z")).contains(next)
  }

  private mutating func scanElementOrTypeParameters() {
    let opening = index
    let saved = (lines: lines, unparsedLine: unparsedLine)
    if scanElement() {
      expectsExpression = false
      return
    }
    index = opening
    lines = saved.lines
    unparsedLine = saved.unparsedLine
    if !startsTypeParameters() {
      markUnparsed(at: opening)
    }
    index += 1
    expectsExpression = true
  }

  private func startsTypeParameters() -> Bool {
    var position = index + 1
    while position < bytes.count, isWordByte(bytes[position]) {
      position += 1
    }
    while position < bytes.count, bytes[position] == ascii(" ") {
      position += 1
    }
    guard position < bytes.count else { return false }
    let rest = bytes[position...]
    return rest.starts(with: Array(",".utf8)) || rest.starts(with: Array("extends ".utf8))
      || rest.starts(with: Array(">(".utf8))
  }

  private enum Tag {
    case open, selfClosing, unclosed
  }

  private mutating func scanElement() -> Bool {
    index += 1
    let name = scanTagName()
    switch scanTag() {
    case .open: return scanChildren(of: name)
    case .selfClosing: return true
    case .unclosed: return false
    }
  }

  private mutating func scanTag() -> Tag {
    while let byte = peek() {
      switch byte {
      case ascii(">"):
        index += 1
        return .open
      case ascii("/") where peek(1) == ascii(">"):
        index += 2
        return .selfClosing
      case ascii("/") where peek(1) == ascii("/"):
        lines.append(line(at: index))
        skipLineComment()
      case ascii("/") where peek(1) == ascii("*"):
        lines.append(line(at: index))
        skipBlockComment()
      case ascii("'"), ascii("\""):
        skipString(quote: byte)
      case ascii("{"):
        index += 1
        expectsExpression = true
        guard scanCode(nested: true) else { return .unclosed }
      default:
        index += 1
      }
    }
    return .unclosed
  }

  private mutating func scanTagName() -> ArraySlice<UInt8> {
    let start = index
    while let byte = peek(),
      isWordByte(byte) || byte == ascii(".") || byte == ascii("-") || byte == ascii(":")
    {
      index += 1
    }
    return bytes[start..<index]
  }

  private mutating func skipSpaces() {
    while let byte = peek(), byte == ascii(" ") || byte == ascii("\t") || byte == ascii("\n") {
      index += 1
    }
  }

  private mutating func scanChildren(of name: ArraySlice<UInt8>) -> Bool {
    while let byte = peek() {
      if byte == ascii("<") && peek(1) == ascii("/") {
        index += 2
        skipSpaces()
        guard scanTagName().elementsEqual(name) else { return false }
        skipSpaces()
        guard peek() == ascii(">") else { return false }
        index += 1
        return true
      } else if byte == ascii("<") {
        guard scanElement() else { return false }
      } else if byte == ascii("{") {
        index += 1
        expectsExpression = true
        guard scanCode(nested: true) else { return false }
      } else {
        index += 1
      }
    }
    return false
  }
}

private func ascii(_ character: Unicode.Scalar) -> UInt8 {
  UInt8(character.value)
}

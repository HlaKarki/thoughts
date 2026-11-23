enum ScriptComments {
  static func lines(in contents: String, jsx: Bool) -> [Int] {
    var scanner = Scanner(bytes: Array(contents.utf8), jsx: jsx)
    scanner.skipShebang()
    scanner.scanCode(nested: false)
    return scanner.lines
  }
}

private struct Scanner {
  let bytes: [UInt8]
  let jsx: Bool
  var index = 0
  var lines: [Int] = []
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

  mutating func scanCode(nested: Bool) {
    var depth = 0
    while let byte = peek() {
      switch byte {
      case ascii(" "), ascii("\t"), ascii("\n"), ascii("\r"):
        index += 1
      case ascii("'"), ascii("\""):
        skipString(quote: byte)
        expectsExpression = false
      case ascii("`"):
        skipTemplate()
        expectsExpression = false
      case ascii("/"):
        if peek(1) == ascii("/") {
          lines.append(line(at: index))
          skipLineComment()
        } else if peek(1) == ascii("*") {
          lines.append(line(at: index))
          skipBlockComment()
        } else if expectsExpression {
          skipRegex()
          expectsExpression = false
        } else {
          index += 1
          expectsExpression = true
        }
      case ascii("<") where jsx && expectsExpression && startsElement():
        scanElement()
        expectsExpression = false
      case ascii("{"):
        depth += 1
        index += 1
        expectsExpression = true
      case ascii("}"):
        if nested && depth == 0 {
          index += 1
          return
        }
        depth -= 1
        index += 1
        expectsExpression = true
      case ascii(")"), ascii("]"):
        index += 1
        expectsExpression = false
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

  private mutating func skipTemplate() {
    index += 1
    while let byte = peek() {
      if byte == ascii("\\") {
        index += 2
      } else if byte == ascii("`") {
        index += 1
        return
      } else if byte == ascii("$") && peek(1) == ascii("{") {
        index += 2
        expectsExpression = true
        scanCode(nested: true)
      } else {
        index += 1
      }
    }
  }

  private mutating func skipRegex() {
    index += 1
    var inClass = false
    while let byte = peek() {
      if byte == ascii("\n") { return }
      index += 1
      if byte == ascii("\\") {
        index += 1
      } else if byte == ascii("[") {
        inClass = true
      } else if byte == ascii("]") {
        inClass = false
      } else if byte == ascii("/") && !inClass {
        break
      }
    }
    while let byte = peek(), isWordByte(byte) {
      index += 1
    }
  }

  private func startsElement() -> Bool {
    guard let next = peek(1) else { return false }
    return next == ascii(">") || (ascii("a")...ascii("z")).contains(next)
      || (ascii("A")...ascii("Z")).contains(next)
  }

  private mutating func scanElement() {
    index += 1
    if scanTag() {
      scanChildren()
    }
  }

  private mutating func scanTag() -> Bool {
    while let byte = peek() {
      switch byte {
      case ascii(">"):
        index += 1
        return true
      case ascii("/") where peek(1) == ascii(">"):
        index += 2
        return false
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
        scanCode(nested: true)
      default:
        index += 1
      }
    }
    return false
  }

  private mutating func scanChildren() {
    while let byte = peek() {
      if byte == ascii("<") && peek(1) == ascii("/") {
        while let closing = peek(), closing != ascii(">") {
          index += 1
        }
        index += 1
        return
      } else if byte == ascii("<") {
        scanElement()
      } else if byte == ascii("{") {
        index += 1
        expectsExpression = true
        scanCode(nested: true)
      } else {
        index += 1
      }
    }
  }
}

private func ascii(_ character: Unicode.Scalar) -> UInt8 {
  UInt8(character.value)
}

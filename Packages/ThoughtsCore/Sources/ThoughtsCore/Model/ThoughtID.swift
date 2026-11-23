public struct ThoughtID: Hashable, Sendable, Codable, CustomStringConvertible {
  public let rawValue: String

  public init?(rawValue: String) {
    guard !rawValue.isEmpty, !rawValue.contains("/") else { return nil }
    self.rawValue = rawValue
  }

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let id = ThoughtID(rawValue: value) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Invalid thought id")
      )
    }
    self = id
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  public var description: String { rawValue }

  public static func random() -> ThoughtID {
    let alphabet = Array("0123456789abcdefghjkmnpqrstvwxyz")
    let value = String((0..<8).map { _ in alphabet.randomElement()! })
    return ThoughtID(rawValue: value)!
  }
}

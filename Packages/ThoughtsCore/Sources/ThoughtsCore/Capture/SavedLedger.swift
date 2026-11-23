import Foundation

public struct SavedEntry: Sendable, Equatable {
  public let file: URL
  public let clipboardCounts: [Int]
  public let text: String?
  public let source: Source

  public init(
    file: URL, clipboardCounts: [Int] = [], text: String? = nil, source: Source = Source()
  ) {
    self.file = file
    self.clipboardCounts = clipboardCounts
    self.text = text
    self.source = source
  }
}

public struct SavedLedger: Sendable, Equatable {
  public static let remembered = 64

  public private(set) var entries: [SavedEntry]

  public init(entries: [SavedEntry] = []) {
    self.entries = entries
  }

  public mutating func record(_ entry: SavedEntry) {
    entries.append(entry)
    if entries.count > Self.remembered { entries.removeFirst() }
  }

  public func pruned(exists: (URL) -> Bool) -> SavedLedger {
    SavedLedger(entries: entries.filter { exists($0.file) })
  }

  public func holdsImage(counts: [Int]) -> Bool {
    entries.contains { entry in entry.clipboardCounts.contains { counts.contains($0) } }
  }

  public func newestIsText(_ text: String, from source: Source) -> Bool {
    guard let newest = entries.last, let saved = newest.text else { return false }
    return Self.trimmed(saved) == Self.trimmed(text) && newest.source == source
  }

  private static func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

public struct IndexChanges: Sendable, Equatable {
  public var added: [String]
  public var updated: [String]
  public var removed: [String]

  public init(added: [String] = [], updated: [String] = [], removed: [String] = []) {
    self.added = added
    self.updated = updated
    self.removed = removed
  }

  public var isEmpty: Bool { added.isEmpty && updated.isEmpty && removed.isEmpty }

  mutating func forget(_ name: String) {
    let key = ExactName(name)
    added.removeAll { ExactName($0) == key }
    updated.removeAll { ExactName($0) == key }
  }

  func touches(_ name: String) -> Bool {
    let key = ExactName(name)
    return [added, updated, removed].contains { $0.contains { ExactName($0) == key } }
  }
}

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

  func touches(_ name: String) -> Bool {
    added.contains(name) || updated.contains(name) || removed.contains(name)
  }
}

import Foundation

public struct TrashedFile: Sendable, Equatable {
  public let original: URL
  public let trashed: URL

  public init(original: URL, trashed: URL) {
    self.original = original
    self.trashed = trashed
  }
}

public enum RestoreError: Error, Equatable, Sendable {
  case notInTrash
  case nameTaken
  case changed
}

public struct ThoughtMark: Sendable, Equatable {
  public var done: Date?
  public var cleared: Bool

  public init(done: Date?, cleared: Bool) {
    self.done = done
    self.cleared = cleared
  }
}

extension Thought {
  public var mark: ThoughtMark { ThoughtMark(done: done, cleared: cleared) }
}

public enum ThoughtChange: Sendable, Equatable {
  case mark(ThoughtMark)
  case text(String)
}

public struct Amendment: Sendable, Equatable {
  public let id: ThoughtID
  public let file: URL
  public let expected: FileVersion
  public let change: ThoughtChange

  public init(id: ThoughtID, file: URL, expected: FileVersion, change: ThoughtChange) {
    self.id = id
    self.file = file
    self.expected = expected
    self.change = change
  }
}

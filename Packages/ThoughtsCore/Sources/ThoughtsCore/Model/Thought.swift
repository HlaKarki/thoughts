import Foundation

public enum ThoughtContent: Sendable, Equatable {
  case text(String)
  case image(fileName: String, note: String)
}

public struct FileVersion: Sendable, Equatable {
  public let modified: Date
  public let size: Int

  public init(modified: Date, size: Int) {
    self.modified = modified
    self.size = size
  }
}

public struct Thought: Identifiable, Sendable, Equatable {
  public let id: ThoughtID
  public var created: Date
  public var done: Date?
  public var cleared: Bool
  public var content: ThoughtContent
  public var source: Source?
  public var extraFrontMatter: String
  public let file: URL
  public var version: FileVersion

  public init(
    id: ThoughtID,
    created: Date,
    done: Date? = nil,
    cleared: Bool = false,
    content: ThoughtContent,
    source: Source? = nil,
    extraFrontMatter: String = "",
    file: URL,
    version: FileVersion
  ) {
    self.id = id
    self.created = created
    self.done = done
    self.cleared = cleared
    self.content = content
    self.source = source
    self.extraFrontMatter = extraFrontMatter
    self.file = file
    self.version = version
  }
}

public enum ThoughtEntry: Sendable, Equatable {
  case thought(Thought)
  case malformed(file: URL, reason: String)
}

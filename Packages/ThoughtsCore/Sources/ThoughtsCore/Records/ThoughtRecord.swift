import Foundation

public struct ThoughtRecord: Codable, Sendable, Equatable {
  public let id: String
  public let created: Date
  public let done: Date?
  public let cleared: Bool
  public let kind: String
  public let text: String?
  public let note: String?
  public let image: String?
  public let file: String
  public let source: Source?

  public init(_ thought: Thought, store: ThoughtStore) {
    id = thought.id.rawValue
    created = thought.created
    done = thought.done
    cleared = thought.cleared
    file = thought.file.path
    source = thought.source
    switch thought.content {
    case .text(let value):
      kind = "text"
      text = value
      note = nil
      image = nil
    case .image(_, let value):
      kind = "image"
      text = nil
      note = value
      image = store.imageURL(of: thought)?.path
    }
  }
}

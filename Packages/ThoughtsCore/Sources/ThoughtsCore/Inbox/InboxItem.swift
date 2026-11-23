import Foundation

public struct InboxItem: Codable, Sendable, Equatable {
  public enum Kind: String, Codable, Sendable {
    case text
    case url
    case file
  }

  public var kind: Kind
  public var text: String?
  public var url: URL?
  public var title: String?
  public var fileName: String?
  public var originalPath: String?
  public var sourceApp: Source?
  public var created: Date

  public init(
    kind: Kind,
    text: String? = nil,
    url: URL? = nil,
    title: String? = nil,
    fileName: String? = nil,
    originalPath: String? = nil,
    sourceApp: Source? = nil,
    created: Date = Date()
  ) {
    self.kind = kind
    self.text = text
    self.url = url
    self.title = title
    self.fileName = fileName
    self.originalPath = originalPath
    self.sourceApp = sourceApp
    self.created = created
  }
}

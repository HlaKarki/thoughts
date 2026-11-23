import Foundation

public struct Source: Codable, Sendable, Equatable {
  public var app: String?
  public var bundleID: String?
  public var window: String?
  public var url: URL?
  public var title: String?
  public var file: String?

  public init(
    app: String? = nil,
    bundleID: String? = nil,
    window: String? = nil,
    url: URL? = nil,
    title: String? = nil,
    file: String? = nil
  ) {
    self.app = app
    self.bundleID = bundleID
    self.window = window
    self.url = url
    self.title = title
    self.file = file
  }
}

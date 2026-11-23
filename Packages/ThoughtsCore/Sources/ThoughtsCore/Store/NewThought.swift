import Foundation
import UniformTypeIdentifiers

public enum ImageInput: Sendable {
  case data(Data, UTType)
  case file(URL)
}

public enum NewContent: Sendable {
  case text(String)
  case image(ImageInput, note: String)
}

public struct NewThought: Sendable {
  public var content: NewContent
  public var source: Source?
  public var created: Date

  public init(content: NewContent, source: Source? = nil, created: Date = Date()) {
    self.content = content
    self.source = source
    self.created = created
  }

  public static func fromFile(_ url: URL, source: Source?, created: Date) -> NewThought {
    var source = source ?? Source()
    source.file = url.path
    let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    let content: NewContent = isImage ? .image(.file(url), note: "") : .text(url.path)
    return NewThought(content: content, source: source, created: created)
  }
}

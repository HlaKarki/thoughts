import Foundation

public enum OfferSignal: Sendable, Equatable {
  case clipboard(changeCount: Int, file: URL?, at: Date)
  case file(URL, at: Date)

  public var date: Date {
    switch self {
    case .clipboard(_, _, let date): date
    case .file(_, let date): date
    }
  }
}

public struct Offer: Sendable, Equatable, Identifiable {
  public let id: OfferID
  public var changeCount: Int?
  public var file: URL?
  public var source: Source?
  public var updated: Date

  public init(
    id: OfferID = OfferID(), changeCount: Int? = nil, file: URL? = nil, source: Source? = nil,
    updated: Date
  ) {
    self.id = id
    self.changeCount = changeCount
    self.file = file
    self.source = source
    self.updated = updated
  }
}

public enum OfferUpdate: Sendable, Equatable {
  case show(Offer)
  case update(Offer)
  case ignore
}

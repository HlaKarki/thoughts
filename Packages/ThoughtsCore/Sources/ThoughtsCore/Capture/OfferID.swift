import Foundation

public struct OfferID: Hashable, Sendable {
  public let rawValue: UUID

  public init() {
    rawValue = UUID()
  }
}

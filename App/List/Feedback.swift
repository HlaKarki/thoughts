import Foundation

struct Feedback: Equatable, Identifiable {
  enum Kind: Equatable {
    case confirmation
    case message
  }

  static let confirmationLifetime: Duration = .milliseconds(1500)
  static let messageLifetime: Duration = .seconds(4)

  let id = UUID()
  let kind: Kind
  let text: String
  var lingers = false

  var lifetime: Duration {
    kind == .confirmation && !lingers ? Self.confirmationLifetime : Self.messageLifetime
  }
}

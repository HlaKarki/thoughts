import Foundation
import Observation

@MainActor
@Observable
final class Preferences {
  @ObservationIgnored private let defaults: UserDefaults

  var edge: PanelEdge {
    didSet { defaults.set(edge.rawValue, forKey: Key.edge) }
  }

  var keepOpen: Bool {
    didSet { defaults.set(keepOpen, forKey: Key.keepOpen) }
  }

  var firstRunDone: Bool {
    didSet { defaults.set(firstRunDone, forKey: Key.firstRunDone) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    edge = defaults.string(forKey: Key.edge).flatMap(PanelEdge.init(rawValue:)) ?? .right
    keepOpen = defaults.bool(forKey: Key.keepOpen)
    firstRunDone = defaults.bool(forKey: Key.firstRunDone)
  }

  private enum Key {
    static let edge = "panelEdge"
    static let keepOpen = "keepOpen"
    static let firstRunDone = "firstRunDone"
  }
}

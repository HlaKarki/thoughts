import Foundation

public enum Modifier: String, Codable, Sendable, CaseIterable {
  case shift, option, control, command
}

public enum ModifierEvent: Sendable, Equatable {
  case modifiers(Set<Modifier>, at: TimeInterval)
  case key(at: TimeInterval)
  case mouseDown(at: TimeInterval)
}

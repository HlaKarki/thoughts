import Foundation

public struct DoubleTapDetector: Sendable {
  private enum Phase: Equatable {
    case idle
    case firstDown(at: TimeInterval)
    case between(released: TimeInterval)
    case secondDown(at: TimeInterval)
  }

  private let modifier: Modifier
  private let maxHold: TimeInterval
  private let maxGap: TimeInterval
  private var held: Set<Modifier> = []
  private var phase = Phase.idle

  public init(modifier: Modifier, maxHold: TimeInterval = 0.25, maxGap: TimeInterval = 0.35) {
    self.modifier = modifier
    self.maxHold = maxHold
    self.maxGap = maxGap
  }

  public mutating func feed(_ event: ModifierEvent) -> Bool {
    switch event {
    case .key:
      phase = .idle
      return false
    case .modifiers(let now, let time):
      let before = held
      held = now
      if now == before { return false }
      if now == [modifier], before.isEmpty { return press(at: time) }
      if now.isEmpty, before == [modifier] { return release(at: time) }
      phase = .idle
      return false
    }
  }

  private mutating func press(at time: TimeInterval) -> Bool {
    if case .between(let released) = phase, time - released <= maxGap {
      phase = .secondDown(at: time)
    } else {
      phase = .firstDown(at: time)
    }
    return false
  }

  private mutating func release(at time: TimeInterval) -> Bool {
    switch phase {
    case .firstDown(let pressed):
      phase = time - pressed <= maxHold ? .between(released: time) : .idle
      return false
    case .secondDown(let pressed):
      phase = .idle
      return time - pressed <= maxHold
    case .idle, .between:
      phase = .idle
      return false
    }
  }
}

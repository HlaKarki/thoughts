enum FirstRunStep: CaseIterable, Equatable {
  case summonKey
  case gesture
  case accessibility
  case storage
  case clipboard
  case done
}

struct FirstRunState: Equatable {
  var summonKeySet: Bool
  var accessibilityGranted: Bool
  var captureReady = true
}

enum FirstRunFlow {
  static let numberedSteps = FirstRunStep.allCases.count - 1

  static func next(after step: FirstRunStep, state: FirstRunState) -> FirstRunStep {
    switch step {
    case .summonKey: state.summonKeySet ? .gesture : .summonKey
    case .gesture: state.captureReady ? .accessibility : .gesture
    case .accessibility: state.accessibilityGranted ? .storage : .accessibility
    case .storage: .clipboard
    case .clipboard: .done
    case .done: .done
    }
  }

  static func previous(before step: FirstRunStep) -> FirstRunStep {
    switch step {
    case .summonKey, .gesture: .summonKey
    case .accessibility: .gesture
    case .storage: .accessibility
    case .clipboard: .storage
    case .done: .clipboard
    }
  }

  static func number(of step: FirstRunStep) -> Int? {
    step == .done ? nil : FirstRunStep.allCases.firstIndex(of: step).map { $0 + 1 }
  }
}

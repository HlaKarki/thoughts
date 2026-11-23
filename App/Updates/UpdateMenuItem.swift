import Observation

@MainActor
@Observable
final class UpdateMenuItem {
  private(set) var isShown = false

  func updateWillShow(handledBySparkle: Bool) {
    if !handledBySparkle { isShown = true }
  }

  func sessionWillFinish() {
    isShown = false
  }
}

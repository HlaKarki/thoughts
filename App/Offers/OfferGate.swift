@MainActor
struct OfferGate {
  let firstRunDone: @MainActor () -> Bool
  let start: @MainActor () -> Void

  func launch() {
    if firstRunDone() { start() }
  }

  func firstRunFinished() {
    start()
  }
}

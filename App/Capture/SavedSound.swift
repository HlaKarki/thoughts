import AppKit

@MainActor
final class SavedSound {
  private let preferences: Preferences
  private let player: @MainActor () -> Void

  init(preferences: Preferences, player: @escaping @MainActor () -> Void = PluckSound.play) {
    self.preferences = preferences
    self.player = player
  }

  func play() {
    guard preferences.soundEnabled else { return }
    player()
  }
}

@MainActor
enum PluckSound {
  private static let sound = Bundle.main.url(forResource: "Pluck", withExtension: "wav")
    .flatMap { NSSound(contentsOf: $0, byReference: false) }

  static func play() {
    sound?.stop()
    sound?.play()
  }
}

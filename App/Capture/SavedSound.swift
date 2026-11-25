import AppKit
import Observation

@MainActor
final class SavedSound {
  private let preferences: Preferences
  private let player: @MainActor () -> Void
  private var wasEnabled: Bool
  private var following = false

  init(preferences: Preferences, player: @escaping @MainActor () -> Void = PluckSound.play) {
    self.preferences = preferences
    self.player = player
    wasEnabled = preferences.soundEnabled
  }

  func start() {
    guard !following else { return }
    following = true
    follow()
  }

  private func follow() {
    withObservationTracking {
      _ = preferences.soundEnabled
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        let enabled = self.preferences.soundEnabled
        if enabled && !self.wasEnabled { self.player() }
        self.wasEnabled = enabled
        self.follow()
      }
    }
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

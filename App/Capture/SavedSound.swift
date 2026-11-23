import AppKit

@MainActor
final class SavedSound {
  private let preferences: Preferences
  private let player: @MainActor () -> Void

  init(preferences: Preferences, player: @escaping @MainActor () -> Void = SystemTink.play) {
    self.preferences = preferences
    self.player = player
  }

  func play() {
    guard preferences.soundEnabled else { return }
    player()
  }
}

@MainActor
enum SystemTink {
  private static let sound = NSSound(named: "Tink")

  static func play() {
    sound?.stop()
    sound?.play()
  }
}

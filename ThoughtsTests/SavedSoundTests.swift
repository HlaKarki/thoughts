import AppKit
import Testing

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct SavedSoundTests {
  @Test func theAppBundlesPluckAndItIsAShortSound() throws {
    let url = try #require(Bundle.main.url(forResource: "Pluck", withExtension: "wav"))
    let sound = try #require(NSSound(contentsOf: url, byReference: false))
    #expect((0.35...0.45).contains(sound.duration))
  }
}

@MainActor
@Suite(.throwaway)
struct LiveSoundTests {
  static func rig(enabled: Bool) throws -> (Preferences, SavedSound, Tally) {
    let defaults = try Throwaway.defaults()
    let preferences = Preferences(defaults: defaults)
    preferences.soundEnabled = enabled
    let plays = Tally()
    let sound = SavedSound(preferences: preferences, player: { plays.count += 1 })
    sound.start()
    return (preferences, sound, plays)
  }

  @Test func turningTheSoundOnPlaysItOnce() async throws {
    let (preferences, sound, plays) = try Self.rig(enabled: false)
    withExtendedLifetime(sound) {}
    preferences.soundEnabled = true
    #expect(await PanelHarness.waitUntil { plays.count == 1 })
    try? await Task.sleep(for: .milliseconds(300))
    #expect(plays.count == 1)
    preferences.soundEnabled = true
    try? await Task.sleep(for: .milliseconds(200))
    #expect(plays.count == 1)
  }

  @Test func turningTheSoundOffPlaysNothing() async throws {
    let (preferences, sound, plays) = try Self.rig(enabled: true)
    withExtendedLifetime(sound) {}
    preferences.soundEnabled = false
    try? await Task.sleep(for: .milliseconds(300))
    #expect(plays.count == 0)
    sound.play()
    #expect(plays.count == 0)
  }

  @Test func turningItOnAgainAfterOffPlaysOnceMore() async throws {
    let (preferences, sound, plays) = try Self.rig(enabled: false)
    withExtendedLifetime(sound) {}
    preferences.soundEnabled = true
    #expect(await PanelHarness.waitUntil { plays.count == 1 })
    preferences.soundEnabled = false
    try? await Task.sleep(for: .milliseconds(200))
    preferences.soundEnabled = true
    #expect(await PanelHarness.waitUntil { plays.count == 2 })
  }
}

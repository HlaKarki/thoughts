import AppKit
import Testing

@testable import Thoughts

@MainActor
struct SavedSoundTests {
  @Test func theAppBundlesPluckAndItIsAShortSound() throws {
    let url = try #require(Bundle.main.url(forResource: "Pluck", withExtension: "wav"))
    let sound = try #require(NSSound(contentsOf: url, byReference: false))
    #expect((0.35...0.45).contains(sound.duration))
  }
}

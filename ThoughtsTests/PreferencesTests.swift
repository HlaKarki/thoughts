import Foundation
import Testing

@testable import Thoughts

@MainActor
struct PreferencesTests {
  static func defaults() throws -> UserDefaults {
    let name = "thoughts.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    return defaults
  }

  @Test func theMenuBarIconIsOnUntilTheUserTurnsItOff() throws {
    let defaults = try Self.defaults()
    let preferences = Preferences(defaults: defaults)
    #expect(preferences.showsMenuBarIcon)
    preferences.showsMenuBarIcon = false
    #expect(!Preferences(defaults: defaults).showsMenuBarIcon)
    preferences.showsMenuBarIcon = true
    #expect(Preferences(defaults: defaults).showsMenuBarIcon)
  }
}

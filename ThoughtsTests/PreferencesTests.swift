import Foundation
import Testing

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct PreferencesTests {
  static func defaults() throws -> UserDefaults {
    let defaults = try Throwaway.defaults()
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

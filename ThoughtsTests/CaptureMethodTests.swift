import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct CaptureMethodTests {
  @Test func freshPreferencesAreTheDoubleShiftTap() throws {
    let preferences = try SettingsFixtures.preferences()
    #expect(preferences.captureMethod == .doubleTap(.shift))
    #expect(preferences.gesture == .shift)
    #expect(!preferences.captureShortcut)
  }

  @Test(arguments: [
    CaptureMethod.doubleTap(.shift), .doubleTap(.option), .doubleTap(.control),
    .doubleTap(.command), .shortcut, .off,
  ])
  func eachMethodRoundTripsThroughPreferences(_ method: CaptureMethod) throws {
    let name = "thoughts.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let preferences = Preferences(defaults: defaults)
    preferences.captureMethod = method
    #expect(Preferences(defaults: defaults).captureMethod == method)
  }

  @Test func choosingTheShortcutKeepsTheDoubleTapModifier() throws {
    let preferences = try SettingsFixtures.preferences()
    preferences.captureMethod = .doubleTap(.option)
    preferences.captureMethod = .shortcut
    #expect(preferences.gesture == .option)
    #expect(preferences.captureMethod.modifier == nil)
    preferences.captureMethod = .doubleTap(.control)
    #expect(!preferences.captureShortcut)
    #expect(preferences.captureMethod.modifier == .control)
  }

  @Test func turningCaptureOffClearsBothMethods() throws {
    let preferences = try SettingsFixtures.preferences()
    preferences.captureMethod = .shortcut
    preferences.captureMethod = .off
    #expect(preferences.gesture == nil)
    #expect(!preferences.captureShortcut)
  }

  @Test func keycapTextFollowsTheMethod() {
    #expect(CaptureMethod.doubleTap(.shift).keycap(shortcut: "⌃⌥K")?.plain == "⇧⇧")
    #expect(CaptureMethod.doubleTap(.command).keycap(shortcut: nil)?.plain == "⌘⌘")
    #expect(CaptureMethod.shortcut.keycap(shortcut: "⌃⌥K")?.plain == "⌃⌥K")
    #expect(CaptureMethod.shortcut.keycap(shortcut: nil) == nil)
    #expect(CaptureMethod.shortcut.keycap(shortcut: "") == nil)
    #expect(CaptureMethod.off.keycap(shortcut: "⌃⌥K") == nil)
  }

  @Test func theShortcutIsRegisteredOnceAndEnabledOnlyForTheShortcutMethod() async throws {
    let log = CallLog()
    let preferences = try SettingsFixtures.preferences()
    let hotkey = ShortcutSwitch(
      register: { _ in log.add("register") },
      unregister: { log.add("unregister") },
      setEnabled: { log.add("enabled \($0)") })
    let shortcut = CaptureShortcut(preferences: preferences, hotkey: hotkey)
    shortcut.start()
    shortcut.start()
    #expect(log.events == ["register", "enabled false"])
    preferences.captureMethod = .shortcut
    await settle()
    preferences.captureMethod = .doubleTap(.option)
    await settle()
    preferences.captureMethod = .off
    await settle()
    #expect(
      log.events == [
        "register", "enabled false", "enabled true", "enabled false",
      ])
    shortcut.stop()
    #expect(log.events.suffix(2) == ["enabled false", "unregister"])
  }

  @Test func theShortcutFiresTheCapturePathOnlyWhileItsMethodIsOn() throws {
    let preferences = try SettingsFixtures.preferences()
    var handler: (@MainActor () -> Void)?
    let hotkey = ShortcutSwitch(
      register: { handler = $0 }, unregister: {}, setEnabled: { _ in })
    let shortcut = CaptureShortcut(preferences: preferences, hotkey: hotkey)
    var fired = 0
    shortcut.onFire = { fired += 1 }
    shortcut.start()
    handler?()
    #expect(fired == 0)
    preferences.captureMethod = .shortcut
    handler?()
    #expect(fired == 1)
    preferences.captureMethod = .doubleTap(.shift)
    handler?()
    #expect(fired == 1)
  }

  private func settle() async {
    for _ in 0..<20 { await Task.yield() }
  }
}

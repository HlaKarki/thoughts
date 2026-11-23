import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct SettingsSnapshotTests {
  static func tone(_ appearance: NSAppearance.Name) -> String {
    appearance == .aqua ? "light" : "dark"
  }

  static func check(
    _ view: some View, size: CGSize, appearance: NSAppearance.Name, name: String
  ) throws {
    let url = try SnapshotRenderer.render(
      view, size: size, appearance: appearance, name: "\(name)-\(tone(appearance))")
    let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
    #expect(bitmap.pixelsWide == Int(size.width) * SnapshotRenderer.scale)
    #expect(bitmap.pixelsHigh == Int(size.height) * SnapshotRenderer.scale)
    #expect(SnapshotTests.colorCount(of: bitmap) > 1)
  }

  static func firstRun(
    step: FirstRunStep, access: NSPasteboard.AccessBehavior = .ask, trusted: Bool = true,
    gesture: Modifier? = .shift
  ) throws -> FirstRunModel {
    let system = FakeSystem()
    system.trusted = trusted
    system.access = access
    let preferences = try SettingsFixtures.preferences()
    preferences.gesture = gesture
    let model = try SettingsFixtures.firstRun(system: system, preferences: preferences)
    let target = FirstRunStep.allCases.firstIndex(of: step) ?? 0
    for _ in 0..<target {
      if model.step == .accessibility && !trusted { break }
      model.advance()
    }
    return model
  }

  static func settings(
    login: LoginStatus = .on, gesture: Modifier? = .shift, withFolder: Bool = true
  ) throws -> SettingsModel {
    let preferences = try SettingsFixtures.preferences()
    preferences.gesture = gesture
    preferences.soundEnabled = false
    if withFolder {
      preferences.watchedFolders = [URL(fileURLWithPath: "/example/home/Pictures/Screenshots")]
    }
    let fakeLogin = FakeLogin()
    fakeLogin.status = login
    let system = FakeSystem()
    system.access = .ask
    return try SettingsFixtures.settings(system: system, preferences: preferences, login: fakeLogin)
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func firstRunSteps(_ appearance: NSAppearance.Name) throws {
    let steps: [(FirstRunStep, String)] = [
      (.summonKey, "1-summon-key"), (.gesture, "2-capture-gesture"),
      (.accessibility, "3-permissions-allowed"), (.storage, "4-storage-folder"),
      (.clipboard, "5-clipboard"), (.done, "6-done"),
    ]
    for (step, name) in steps {
      let model = try Self.firstRun(step: step)
      #expect(model.step == step)
      try Self.check(
        FirstRunView(model: model), size: FirstRunView.size, appearance: appearance,
        name: "first-run-\(name)")
    }
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func firstRunVariants(_ appearance: NSAppearance.Name) throws {
    let waiting = try Self.firstRun(step: .accessibility, trusted: false)
    #expect(waiting.step == .accessibility)
    #expect(!waiting.canContinue)
    try Self.check(
      FirstRunView(model: waiting), size: FirstRunView.size, appearance: appearance,
      name: "first-run-3-permissions-waiting")
    let alwaysAllowed = try Self.firstRun(step: .clipboard, access: .alwaysAllow)
    try Self.check(
      FirstRunView(model: alwaysAllowed), size: FirstRunView.size, appearance: appearance,
      name: "first-run-5-clipboard-always-allow")
    let gestureOff = try Self.firstRun(step: .clipboard, gesture: nil)
    try Self.check(
      FirstRunView(model: gestureOff), size: FirstRunView.size, appearance: appearance,
      name: "first-run-5-clipboard-gesture-off")
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func settingsWindowAndSections(_ appearance: NSAppearance.Name) throws {
    let model = try Self.settings()
    try Self.check(
      SettingsView(model: model), size: SettingsView.size, appearance: appearance,
      name: "settings")
    let width = SettingsView.size.width - 44
    let sections: [(String, AnyView, CGFloat)] = [
      (
        "settings-keys",
        AnyView(SettingsGroup(title: "Keys") { KeysSettings(preferences: model.preferences) }),
        150
      ),
      (
        "settings-saving",
        AnyView(SettingsGroup(title: "Saving") { SavingSettings(model: model) }), 500
      ),
      (
        "settings-panel",
        AnyView(SettingsGroup(title: "Panel") { PanelSettings(model: model) }), 140
      ),
    ]
    for (name, view, height) in sections {
      try Self.check(
        view.frame(width: width, alignment: .topLeading).padding(11),
        size: CGSize(width: width + 22, height: height), appearance: appearance, name: name)
    }
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func settingsStates(_ appearance: NSAppearance.Name) throws {
    let approval = try Self.settings(login: .requiresApproval, gesture: nil, withFolder: false)
    try Self.check(
      SettingsView(model: approval), size: SettingsView.size, appearance: appearance,
      name: "settings-login-approval")
  }
}

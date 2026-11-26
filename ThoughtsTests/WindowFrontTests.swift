import AppKit
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct WindowFrontTests {
  @MainActor
  final class Fronting {
    var events: [String] = []
    var windows: [NSWindow] = []
    private var hidden = true

    var front: WindowFront {
      WindowFront(
        visibility: AppVisibility(
          isHidden: { self.hidden },
          unhide: {
            self.hidden = false
            self.events.append("unhide")
          }),
        activateIgnoringOtherApps: { self.events.append("activate ignoring other apps") },
        makeKey: {
          self.windows.append($0)
          self.events.append("make key")
        },
        orderFrontRegardless: { _ in self.events.append("order front regardless") })
    }
  }

  static let fromBehindAnotherApp = [
    "activate ignoring other apps", "unhide", "make key", "order front regardless",
  ]
  static let again = ["activate ignoring other apps", "make key", "order front regardless"]

  @Test func theFirstRunWindowComesInFrontOfTheActiveAppAndBecomesKey() throws {
    let fronting = Fronting()
    let preferences = try SettingsFixtures.preferences()
    let controller = FirstRunWindowController(front: fronting.front) {
      try! SettingsFixtures.firstRun(system: FakeSystem(), preferences: preferences)
    }
    controller.show()
    #expect(fronting.events == Self.fromBehindAnotherApp)
    controller.show()
    #expect(fronting.events == Self.fromBehindAnotherApp + Self.again)
    #expect(fronting.windows.count == 2)
    #expect(fronting.windows.first === fronting.windows.last)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func theFirstRunWindowComesBackInFrontWhenAccessibilityIsTurnedOn() async throws {
    let fronting = Fronting()
    let system = FakeSystem()
    let preferences = try SettingsFixtures.preferences()
    var made: FirstRunModel?
    var reinstalls = 0
    let controller = FirstRunWindowController(front: fronting.front) {
      let model = try! SettingsFixtures.firstRun(system: system, preferences: preferences)
      model.onAccessibilityGranted = { reinstalls += 1 }
      made = model
      return model
    }
    controller.show()
    let model = try #require(made)
    #expect(fronting.events == Self.fromBehindAnotherApp)
    let watching = Task { await model.watchAccessibility() }
    system.trusted = true
    await watching.value
    #expect(fronting.events == Self.fromBehindAnotherApp + Self.again)
    #expect(reinstalls == 1)
    #expect(fronting.windows.count == 2)
    #expect(fronting.windows.first === fronting.windows.last)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func theSettingsWindowComesInFrontOfTheActiveAppAndBecomesKey() throws {
    let fronting = Fronting()
    let preferences = try SettingsFixtures.preferences()
    let controller = SettingsWindowController(front: fronting.front) {
      try! SettingsFixtures.settings(system: FakeSystem(), preferences: preferences)
    }
    controller.show()
    #expect(fronting.events == Self.fromBehindAnotherApp)
    controller.show()
    #expect(fronting.events == Self.fromBehindAnotherApp + Self.again)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func theLaunchFailureAlertComesToTheFrontBeforeItWaitsForAClick() {
    let fronting = Fronting()
    let alert = LaunchFailure.alert(for: ThoughtsError.io("disk"))
    var ran: [String] = []
    LaunchFailure.show(alert, front: fronting.front) { shown in
      ran.append(shown.messageText)
      ran.append(contentsOf: fronting.events)
    }
    #expect(ran == ["Thoughts can't start"] + Self.fromBehindAnotherApp)
    #expect(fronting.windows.first === alert.window)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }
}

import AppKit
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct AccessibilityTrustTests {
  @MainActor
  final class Monitors {
    var installs = 0
    var removals = 0

    var events: EventMonitors {
      EventMonitors(
        addGlobal: { _, _ in
          self.installs += 1
          return NSObject()
        },
        addLocal: { _, _ in NSObject() },
        remove: { _ in self.removals += 1 })
    }
  }

  @MainActor
  final class Rig {
    let system = FakeSystem()
    let monitors = Monitors()
    let preferences: Preferences
    let gesture: GestureMonitor
    let trust: AccessibilityTrustWatch
    let center: NotificationCenter
    let name: Notification.Name

    init(
      trusted: Bool, center: NotificationCenter = NotificationCenter(),
      name: Notification.Name = AccessibilityTrustWatch.changed
    ) throws {
      self.center = center
      self.name = name
      system.trusted = trusted
      preferences = try SettingsFixtures.preferences()
      preferences.captureMethod = .doubleTap(.shift)
      gesture = GestureMonitor(preferences: preferences, monitors: monitors.events)
      let system = system
      trust = AccessibilityTrustWatch(isTrusted: { system.trusted }, center: center, name: name)
      trust.onGranted = { [gesture] in gesture.reinstall() }
      gesture.start()
      trust.start()
    }

    func trustChanged() {
      center.post(name: name, object: nil)
    }

    func firstRun() throws -> FirstRunModel {
      let model = try SettingsFixtures.firstRun(system: system, preferences: preferences)
      model.onAccessibilityGranted = { [trust] in trust.check() }
      return model
    }

    func stop() {
      trust.stop()
      gesture.stop()
    }
  }

  static func settle() async {
    try? await Task.sleep(for: .milliseconds(200))
  }

  @Test func aGrantMadeInSystemSettingsAfterLaunchTurnsTheGestureOnWithoutARestart() async throws {
    let rig = try Rig(trusted: false)
    defer { rig.stop() }
    #expect(rig.monitors.installs == 1)
    rig.system.trusted = true
    rig.trustChanged()
    #expect(
      await PanelHarness.waitUntil { rig.monitors.installs == 2 },
      "the gesture was not installed again after the grant")
  }

  @Test func trustTurnedOffLeavesTheGestureAloneAndAGrantAfterThatTurnsItBackOn() async throws {
    let rig = try Rig(trusted: true)
    defer { rig.stop() }
    #expect(rig.monitors.installs == 1)
    rig.system.trusted = false
    rig.trustChanged()
    await Self.settle()
    #expect(rig.monitors.installs == 1)
    #expect(rig.monitors.removals == 0)
    rig.system.trusted = true
    rig.trustChanged()
    #expect(
      await PanelHarness.waitUntil { rig.monitors.installs == 2 },
      "the gesture was not installed again after trust came back")
  }

  @Test func aTrustCheckCatchesAGrantThatSentNoNotification() throws {
    let rig = try Rig(trusted: false)
    defer { rig.stop() }
    rig.trust.check()
    #expect(rig.monitors.installs == 1)
    rig.system.trusted = true
    rig.trust.check()
    #expect(rig.monitors.installs == 2)
    rig.trust.check()
    #expect(rig.monitors.installs == 2)
  }

  @Test func theFirstRunGrantThenTheNotificationTurnTheGestureOnOnce() async throws {
    let rig = try Rig(trusted: false)
    defer { rig.stop() }
    let model = try rig.firstRun()
    let watching = Task { await model.watchAccessibility() }
    rig.system.trusted = true
    await watching.value
    #expect(rig.monitors.installs == 2)
    rig.trustChanged()
    await Self.settle()
    #expect(rig.monitors.installs == 2)
  }

  @Test func theNotificationThenTheFirstRunGrantTurnTheGestureOnOnce() async throws {
    let rig = try Rig(trusted: false)
    defer { rig.stop() }
    let model = try rig.firstRun()
    rig.system.trusted = true
    rig.trustChanged()
    #expect(await PanelHarness.waitUntil { rig.monitors.installs == 2 })
    await model.watchAccessibility()
    #expect(model.state.accessibilityGranted)
    #expect(rig.monitors.installs == 2)
  }

  @Test func theTrustNotificationArrivesThroughTheDistributedCenter() async throws {
    let rig = try Rig(
      trusted: false, center: DistributedNotificationCenter.default(),
      name: Notification.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { rig.stop() }
    rig.system.trusted = true
    rig.trustChanged()
    #expect(
      await PanelHarness.waitUntil { rig.monitors.installs == 2 },
      "the distributed trust notification did not arrive")
  }
}

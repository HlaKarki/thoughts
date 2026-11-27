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

  final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var waitCount = 0
    private var cancelCount = 0

    var waits: Int { lock.withLock { waitCount } }
    var cancels: Int { lock.withLock { cancelCount } }

    func open() {
      lock.withLock { isOpen = true }
    }

    func wait() async throws {
      lock.withLock { waitCount += 1 }
      while !lock.withLock({ isOpen }) {
        do {
          try await Task.sleep(for: .milliseconds(5))
        } catch {
          lock.withLock { cancelCount += 1 }
          throw error
        }
      }
    }
  }

  @MainActor
  final class Rig {
    let system = FakeSystem()
    let monitors = Monitors()
    let gate = Gate()
    var refreshes = 0
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
      let gate = gate
      var refresh: @MainActor () -> Void = {}
      trust = AccessibilityTrustWatch(
        isTrusted: { system.services.accessibilityTrusted() }, refreshAnswer: { refresh() },
        center: center, name: name, recheckDelay: { try await gate.wait() })
      refresh = { [unowned self] in
        refreshes += 1
        system.staleAnswer = nil
        center.post(name: name, object: nil)
      }
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

  @Test func aGrantThatLandsJustAfterTheNotificationIsCaughtByTheDeferredCheck() async throws {
    let rig = try Rig(trusted: false)
    defer { rig.stop() }
    rig.trustChanged()
    #expect(
      await PanelHarness.waitUntil { rig.gate.waits == 1 }, "no deferred check was scheduled")
    #expect(rig.monitors.installs == 1)
    rig.system.trusted = true
    rig.gate.open()
    #expect(
      await PanelHarness.waitUntil { rig.monitors.installs == 2 },
      "the deferred check did not turn the gesture on")
  }

  @Test func aGrantReadTooEarlyByMacOSIsCaughtByRefreshingTheAnswer() async throws {
    let rig = try Rig(trusted: false)
    defer { rig.stop() }
    let model = try rig.firstRun()
    let watching = Task { await model.watchAccessibility() }
    rig.system.staleAnswer = false
    rig.system.trusted = true
    rig.trustChanged()
    rig.gate.open()
    #expect(
      await PanelHarness.waitUntil { rig.monitors.installs == 2 },
      "the stale answer kept the gesture off")
    #expect(
      await PanelHarness.waitUntil { model.state.accessibilityGranted },
      "the stale answer kept first run on the Accessibility step")
    watching.cancel()
    #expect(rig.refreshes == 1)
  }

  @Test func anAnswerThatStaysDeniedIsRefreshedOnceForEachChange() async throws {
    let rig = try Rig(trusted: false)
    defer { rig.stop() }
    rig.gate.open()
    rig.trustChanged()
    #expect(await PanelHarness.waitUntil { rig.refreshes == 1 }, "the answer was never refreshed")
    await Self.settle()
    #expect(rig.refreshes == 1)
    rig.trustChanged()
    #expect(await PanelHarness.waitUntil { rig.refreshes == 2 })
    await Self.settle()
    #expect(rig.refreshes == 2)
    #expect(rig.monitors.installs == 1)
  }

  @Test func stoppingBeforeTheDeferredCheckCancelsIt() async throws {
    let rig = try Rig(trusted: false)
    rig.trustChanged()
    #expect(
      await PanelHarness.waitUntil { rig.gate.waits == 1 }, "no deferred check was scheduled")
    rig.system.trusted = true
    rig.stop()
    #expect(await PanelHarness.waitUntil { rig.gate.cancels == 1 }, "stop did not cancel it")
    rig.gate.open()
    await Self.settle()
    #expect(rig.monitors.installs == 1)
  }

  @Test func aNewerNotificationReplacesTheDeferredCheck() async throws {
    let rig = try Rig(trusted: false)
    defer { rig.stop() }
    rig.trustChanged()
    #expect(await PanelHarness.waitUntil { rig.gate.waits == 1 })
    rig.trustChanged()
    #expect(await PanelHarness.waitUntil { rig.gate.waits == 2 && rig.gate.cancels == 1 })
    rig.system.trusted = true
    rig.gate.open()
    #expect(await PanelHarness.waitUntil { rig.monitors.installs == 2 })
    await Self.settle()
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

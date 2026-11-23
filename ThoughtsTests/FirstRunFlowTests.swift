import AppKit
import Foundation
import ServiceManagement
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct FirstRunFlowTests {
  @Test func waitsOnAccessibilityUntilGranted() {
    let waiting = FirstRunState(summonKeySet: true, accessibilityGranted: false)
    let granted = FirstRunState(summonKeySet: true, accessibilityGranted: true)
    #expect(FirstRunFlow.next(after: .accessibility, state: waiting) == .accessibility)
    #expect(FirstRunFlow.next(after: .accessibility, state: granted) == .storage)
  }

  @Test func accessibilityLeadsToStorage() {
    let state = FirstRunState(summonKeySet: true, accessibilityGranted: true)
    #expect(FirstRunFlow.next(after: .accessibility, state: state) == .storage)
    #expect(FirstRunFlow.next(after: .gesture, state: state) == .accessibility)
  }

  @Test func waitsForSummonKey() {
    let none = FirstRunState(summonKeySet: false, accessibilityGranted: true)
    let set = FirstRunState(summonKeySet: true, accessibilityGranted: true)
    #expect(FirstRunFlow.next(after: .summonKey, state: none) == .summonKey)
    #expect(FirstRunFlow.next(after: .summonKey, state: set) == .gesture)
  }

  @Test func gestureStartsAsDoubleShift() throws {
    #expect(try SettingsFixtures.preferences().gesture == .shift)
  }

  @Test func stepsRunInOrderAndBackStepsReverseThem() {
    let state = FirstRunState(summonKeySet: true, accessibilityGranted: true)
    var step = FirstRunStep.summonKey
    var seen = [step]
    while FirstRunFlow.next(after: step, state: state) != step {
      step = FirstRunFlow.next(after: step, state: state)
      seen.append(step)
    }
    #expect(seen == FirstRunStep.allCases)
    #expect(FirstRunFlow.previous(before: .summonKey) == .summonKey)
    #expect(FirstRunFlow.previous(before: .storage) == .accessibility)
  }

  @Test func pollerReturnsOnceTheCheckPasses() async {
    var checks = 0
    let poller = PermissionPoller(
      isTrusted: {
        checks += 1
        return checks == 4
      }, interval: .milliseconds(1))
    await poller.waitForAccessibility()
    #expect(checks == 4)
  }

  @Test func pollerStopsWhenCancelled() async {
    let poller = PermissionPoller(isTrusted: { false }, interval: .milliseconds(1))
    let task = Task { await poller.waitForAccessibility() }
    task.cancel()
    await task.value
  }

  @Test func grantRestartsTheGestureMonitorOnce() async throws {
    let system = FakeSystem()
    let model = try SettingsFixtures.firstRun(
      system: system, preferences: SettingsFixtures.preferences())
    var restarts = 0
    model.onAccessibilityGranted = { restarts += 1 }
    let watching = Task { await model.watchAccessibility() }
    try await Task.sleep(for: .milliseconds(10))
    #expect(restarts == 0)
    system.trusted = true
    await watching.value
    await model.watchAccessibility()
    #expect(model.state.accessibilityGranted)
    #expect(restarts == 1)
  }

  @Test func accessibilityButtonPromptsOnceThenOpensThePane() throws {
    let system = FakeSystem()
    let model = try SettingsFixtures.firstRun(
      system: system, preferences: SettingsFixtures.preferences())
    model.openAccessibility()
    #expect(system.requested == 1)
    #expect(system.opened.isEmpty)
    model.openAccessibility()
    #expect(system.requested == 1)
    #expect(system.opened == [SystemServices.accessibilityPane])
  }

  @Test func clipboardStepReadsEachWatchedFolderOnce() throws {
    let system = FakeSystem()
    system.trusted = true
    let preferences = try SettingsFixtures.preferences()
    let extra = URL(fileURLWithPath: "/example/home/Pictures/Shots", isDirectory: true)
    preferences.watchedFolders = [extra]
    let model = try SettingsFixtures.firstRun(system: system, preferences: preferences)
    for _ in 0..<4 { model.advance() }
    #expect(model.step == .clipboard)
    #expect(system.read.map(\.path) == ["/example/home/Desktop", extra.path])
  }

  @Test func clipboardNoteShowsOnlyWhenMacOSWillAsk() throws {
    let system = FakeSystem()
    system.trusted = true
    let model = try SettingsFixtures.firstRun(
      system: system, preferences: SettingsFixtures.preferences())
    for _ in 0..<4 { model.advance() }
    #expect(!model.showsClipboardPromptNote)
    system.access = .ask
    model.back()
    model.advance()
    #expect(model.showsClipboardPromptNote)
  }

  @Test func finishingMarksFirstRunDoneAndOpensThePanel() throws {
    let system = FakeSystem()
    system.trusted = true
    let preferences = try SettingsFixtures.preferences()
    let model = try SettingsFixtures.firstRun(system: system, preferences: preferences)
    var finished = 0
    model.onFinish = { finished += 1 }
    for _ in 0..<4 { model.advance() }
    #expect(model.step == .clipboard)
    #expect(!preferences.firstRunDone)
    #expect(finished == 0)
    model.advance()
    #expect(preferences.firstRunDone)
    #expect(finished == 1)
    #expect(model.step == .clipboard)
  }

  @Test func clipboardIsTheLastStepAnyoneSees() {
    let state = FirstRunState(summonKeySet: true, accessibilityGranted: true)
    #expect(FirstRunFlow.next(after: .clipboard, state: state) == .done)
    #expect(FirstRunFlow.numberedSteps == 5)
    #expect(FirstRunFlow.number(of: .clipboard) == 5)
    #expect(FirstRunFlow.number(of: .done) == nil)
  }

  @Test func theShortcutMethodWaitsForAShortcut() throws {
    let preferences = try SettingsFixtures.preferences()
    preferences.captureMethod = .shortcut
    let model = try SettingsFixtures.firstRun(system: FakeSystem(), preferences: preferences)
    model.advance()
    #expect(model.step == .gesture)
    #expect(!model.canContinue)
    #expect(model.captureKeycap == nil)
    preferences.captureMethod = .doubleTap(.shift)
    model.captureChanged()
    #expect(model.canContinue)
    #expect(model.captureKeycap == .doubled(.shift))
  }

  @Test func aRecordedShortcutLetsTheFlowContinue() throws {
    let preferences = try SettingsFixtures.preferences()
    preferences.captureMethod = .shortcut
    let model = try SettingsFixtures.firstRun(
      system: FakeSystem(), preferences: preferences, captureShortcutText: "⌃⌥K")
    model.advance()
    #expect(model.canContinue)
    #expect(model.captureKeycap == .text("⌃⌥K"))
  }

  @Test func choosingTheFolderRestartsTheIndexOnIt() async throws {
    let system = FakeSystem()
    let log = CallLog()
    let target = SettingsFixtures.home.appendingPathComponent("Notes", isDirectory: true)
    system.picks = [target]
    let model = try SettingsFixtures.firstRun(
      system: system, preferences: SettingsFixtures.preferences(),
      mover: SettingsFixtures.mover(log: log))
    await model.changeStorage()
    #expect(log.events == ["stop", "apply \(target.path)", "restart"])
  }

  @Test(arguments: [
    (LaunchKind.login, true, LaunchAction.nothing),
    (LaunchKind.manual, true, LaunchAction.showPanel),
    (LaunchKind.login, false, LaunchAction.firstRun),
    (LaunchKind.manual, false, LaunchAction.firstRun),
    (LaunchKind.url, true, LaunchAction.nothing),
    (LaunchKind.url, false, LaunchAction.firstRun),
  ])
  func launchDecidesWhatToShow(kind: LaunchKind, done: Bool, expected: LaunchAction) {
    #expect(LaunchAction.decide(firstRunDone: done, kind: kind) == expected)
  }

  @Test func loginLaunchIsTheLoginItemAppleEventFlag() {
    #expect(LaunchKind.from(propData: OSType(keyAELaunchedAsLogInItem)) == .login)
    #expect(LaunchKind.from(propData: OSType(keyAELaunchedAsServiceItem)) == .manual)
    #expect(LaunchKind.from(propData: nil) == .manual)
  }

  @Test func serviceStatusesMapToLoginStatuses() {
    #expect(LoginItem.status(for: .enabled) == .on)
    #expect(LoginItem.status(for: .requiresApproval) == .requiresApproval)
    #expect(LoginItem.status(for: .notRegistered) == .off)
    #expect(LoginItem.status(for: .notFound) == .off)
  }
}

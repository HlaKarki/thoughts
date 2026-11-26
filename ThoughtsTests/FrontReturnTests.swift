import AppKit
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct FrontReturnTests {
  final class Checks: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var waitCount = 0
    private var passCount = 0
    private var cancelCount = 0

    var waits: Int { lock.withLock { waitCount } }
    var cancels: Int { lock.withLock { cancelCount } }
    var settled: Bool { lock.withLock { passCount + cancelCount >= waitCount } }

    func open() {
      lock.withLock { isOpen = true }
    }

    func close() {
      lock.withLock { isOpen = false }
    }

    func wait() async throws {
      lock.withLock { waitCount += 1 }
      while !lock.withLock({ isOpen }) {
        do {
          try await Task.sleep(for: .milliseconds(2))
        } catch {
          lock.withLock { cancelCount += 1 }
          throw error
        }
      }
      lock.withLock { passCount += 1 }
    }
  }

  @MainActor
  final class Outcomes {
    var backs = 0
    var others = 0
  }

  @MainActor
  final class Apps {
    static let own = AppSnapshot(pid: 4101, bundleID: "dev.example.thoughts", name: "Thoughts")
    static let settings = AppSnapshot(
      pid: 4102, bundleID: FrontReturn.systemSettings, name: "System Settings")
    static let finder = AppSnapshot(pid: 4103, bundleID: "com.apple.finder", name: "Finder")
    static let editor = AppSnapshot(pid: 4104, bundleID: "com.example.editor", name: "Editor")
    static let folderPrompt = AppSnapshot(
      pid: 4105, bundleID: FrontReturn.folderPrompt, name: "UserNotificationCenter")
    static let accessibilityAlert = AppSnapshot(
      pid: 4106, bundleID: FrontReturn.accessibilityAlert, name: "universalAccessAuthWarn")

    let center = NotificationCenter()
    var front: AppSnapshot? = Apps.own
    var windows: Set<Int32> = [Apps.own.pid, Apps.finder.pid, Apps.editor.pid]
    var settingsLaunched = false
    let checks = Checks()

    lazy var returns = FrontReturn(
      center: center, ownBundleID: Apps.own.bundleID,
      frontmost: { [unowned self] in front },
      app: { $0.userInfo?["app"] as? AppSnapshot },
      showsWindow: { [unowned self] in windows.contains($0) },
      settingsLaunched: { [unowned self] _ in settingsLaunched },
      recheckDelay: { [checks] in try await checks.wait() })

    func runChecks(after scheduled: Int) async {
      #expect(await PanelHarness.waitUntil(within: .seconds(2)) { checks.waits >= scheduled })
      checks.open()
      _ = await PanelHarness.waitUntil(within: .seconds(2)) { checks.settled }
      try? await Task.sleep(for: .milliseconds(30))
      checks.close()
    }

    func watch() -> (Outcomes, @MainActor () -> Void) {
      let outcomes = Outcomes()
      let done = returns.watchRead(
        back: { outcomes.backs += 1 }, otherwise: { outcomes.others += 1 })
      return (outcomes, done)
    }

    func activate(_ app: AppSnapshot) {
      front = app
      windows.insert(app.pid)
      post(NSWorkspace.didActivateApplicationNotification, app)
    }

    func close(_ app: AppSnapshot) {
      windows.remove(app.pid)
    }

    func hide(_ app: AppSnapshot) {
      windows.remove(app.pid)
      post(NSWorkspace.didHideApplicationNotification, app)
    }

    func terminate(_ app: AppSnapshot) {
      windows.remove(app.pid)
      post(NSWorkspace.didTerminateApplicationNotification, app)
    }

    func quitSettings(fallbackFirst: Bool) {
      close(Self.settings)
      if fallbackFirst {
        activate(Self.finder)
        terminate(Self.settings)
      } else {
        terminate(Self.settings)
        activate(Self.finder)
      }
    }

    func answerFolderPrompt() {
      close(Self.folderPrompt)
      activate(Self.finder)
    }

    private func post(_ name: Notification.Name, _ app: AppSnapshot) {
      center.post(name: name, object: nil, userInfo: ["app": app])
    }
  }

  @Test(arguments: [true, false])
  func systemSettingsQuittingWhileItIsTheActiveAppBringsTheWindowBackOnce(_ fallbackFirst: Bool) {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.openedSystemSettings()
    apps.activate(Apps.settings)
    #expect(backs == 0)
    apps.quitSettings(fallbackFirst: fallbackFirst)
    #expect(backs == 1)
    apps.activate(Apps.settings)
    apps.quitSettings(fallbackFirst: fallbackFirst)
    #expect(backs == 1)
  }

  @Test func systemSettingsQuittingAfterThePersonChoseAnotherAppLeavesTheFrontAlone() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.openedSystemSettings()
    apps.activate(Apps.settings)
    apps.activate(Apps.editor)
    apps.terminate(Apps.settings)
    #expect(backs == 0)
  }

  @Test func hidingSystemSettingsCountsAsChoosingTheAppThatComesUp() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.openedSystemSettings()
    apps.activate(Apps.settings)
    apps.hide(Apps.settings)
    apps.activate(Apps.finder)
    apps.terminate(Apps.settings)
    #expect(backs == 0)
  }

  @Test func systemSettingsQuittingAfterThoughtsCameBackOnItsOwnBringsNothing() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.openedSystemSettings()
    apps.activate(Apps.settings)
    apps.activate(Apps.own)
    apps.terminate(Apps.settings)
    #expect(backs == 0)
  }

  @Test func aSystemSettingsWindowOffScreenStillLeavesTheFrontToAppsChosenAfterIt() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.openedSystemSettings()
    apps.activate(Apps.settings)
    apps.close(Apps.settings)
    apps.activate(Apps.editor)
    apps.activate(Apps.finder)
    apps.terminate(Apps.settings)
    #expect(backs == 0)
  }

  @Test func nothingIsWatchedWhenThoughtsIsNotTheFrontApp() {
    let apps = Apps()
    apps.front = Apps.editor
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.openedSystemSettings()
    hooks.askedForAccessibility()
    let done = hooks.read()
    apps.activate(Apps.accessibilityAlert)
    apps.close(Apps.accessibilityAlert)
    apps.activate(Apps.settings)
    apps.activate(Apps.folderPrompt)
    apps.close(Apps.folderPrompt)
    apps.activate(Apps.settings)
    done()
    apps.quitSettings(fallbackFirst: true)
    #expect(backs == 0)
  }

  @Test(arguments: [true, false])
  func aFolderPromptBringsTheWindowBackOnceTheReadLandsAndThePromptIsGone(_ readFirst: Bool) {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    let done = hooks.read()
    apps.activate(Apps.folderPrompt)
    apps.close(Apps.folderPrompt)
    if readFirst {
      done()
      #expect(backs == 0)
      apps.activate(Apps.finder)
    } else {
      apps.activate(Apps.finder)
      #expect(backs == 0)
      done()
    }
    #expect(backs == 1)
    apps.activate(Apps.editor)
    done()
    #expect(backs == 1)
  }

  @Test func anotherAppActivatingWhileThePromptWindowStaysUpThroughTheCheckIsAChoice() async {
    let apps = Apps()
    let (outcomes, done) = apps.watch()
    apps.activate(Apps.folderPrompt)
    apps.activate(Apps.editor)
    #expect(outcomes.others == 0)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.waits == 1 })
    await apps.runChecks(after: 1)
    #expect(outcomes.others == 1)
    apps.close(Apps.folderPrompt)
    done()
    apps.activate(Apps.finder)
    #expect(outcomes.backs == 0)
    #expect(outcomes.others == 1)
  }

  @Test(arguments: [true, false])
  func aFallbackWhileThePromptWindowStillShowsBringsTheWindowBackWhenItIsGoneAtTheCheck(
    _ readFirst: Bool
  ) async {
    let apps = Apps()
    let (outcomes, done) = apps.watch()
    apps.activate(Apps.folderPrompt)
    if readFirst { done() }
    apps.activate(Apps.finder)
    if !readFirst { done() }
    #expect(outcomes.backs == 0)
    #expect(outcomes.others == 0)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.waits == 1 })
    apps.close(Apps.folderPrompt)
    await apps.runChecks(after: 1)
    #expect(outcomes.backs == 1)
    #expect(outcomes.others == 0)
  }

  @Test func aPromptActivationDuringTheWaitCancelsTheCheckAndKeepsWatching() async {
    let apps = Apps()
    let (outcomes, done) = apps.watch()
    apps.activate(Apps.folderPrompt)
    apps.activate(Apps.editor)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.waits == 1 })
    apps.activate(Apps.folderPrompt)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.cancels == 1 })
    apps.answerFolderPrompt()
    done()
    #expect(outcomes.backs == 1)
    #expect(outcomes.others == 0)
  }

  @Test(arguments: [true, false])
  func anotherAppActivatingAfterTheFallbackButBeforeTheCheckIsAChoice(_ readFirst: Bool) async {
    let apps = Apps()
    let (outcomes, done) = apps.watch()
    apps.activate(Apps.folderPrompt)
    if readFirst { done() }
    apps.activate(Apps.finder)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.waits == 1 })
    apps.close(Apps.folderPrompt)
    apps.activate(Apps.editor)
    if !readFirst { done() }
    #expect(outcomes.backs == 0)
    #expect(outcomes.others == 1)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.cancels == 1 })
    await apps.runChecks(after: 1)
    #expect(outcomes.backs == 0)
    #expect(outcomes.others == 1)
  }

  @Test func aWatchThatEndsBeforeItsCheckFiresLeavesNothingBehind() async {
    let apps = Apps()
    let (outcomes, done) = apps.watch()
    apps.activate(Apps.folderPrompt)
    apps.activate(Apps.finder)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.waits == 1 })
    apps.activate(Apps.own)
    #expect(outcomes.others == 1)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.cancels == 1 })
    apps.close(Apps.folderPrompt)
    await apps.runChecks(after: 1)
    done()
    apps.activate(Apps.finder)
    #expect(outcomes.backs == 0)
    #expect(outcomes.others == 1)
    #expect(apps.checks.waits == 1)
  }

  @Test func choosingAnotherAppAfterThePromptEndedButBeforeTheReadLandedLeavesTheFrontAlone() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    let done = hooks.read()
    apps.activate(Apps.folderPrompt)
    apps.answerFolderPrompt()
    apps.activate(Apps.editor)
    done()
    #expect(backs == 0)
  }

  @Test func aReadThatNeverPromptedBringsNothing() {
    let apps = Apps()
    var backs = 0
    var others = 0
    let done = apps.returns.watchRead(back: { backs += 1 }, otherwise: { others += 1 })
    done()
    apps.activate(Apps.finder)
    done()
    #expect(backs == 0)
    #expect(others == 1)
  }

  @Test func thoughtsBecomingActiveDuringAReadEndsTheWatchWithoutABring() {
    let apps = Apps()
    apps.front = Apps.finder
    var backs = 0
    var others = 0
    let done = apps.returns.watchRead(back: { backs += 1 }, otherwise: { others += 1 })
    apps.activate(Apps.folderPrompt)
    apps.activate(Apps.own)
    apps.close(Apps.folderPrompt)
    done()
    apps.activate(Apps.finder)
    #expect(backs == 0)
    #expect(others == 1)
  }

  @Test func aSecondPromptInTheSameReadWaitsForTheLastAnswer() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    let done = hooks.read()
    apps.activate(Apps.folderPrompt)
    apps.answerFolderPrompt()
    apps.activate(Apps.folderPrompt)
    #expect(backs == 0)
    apps.close(Apps.folderPrompt)
    done()
    #expect(backs == 0)
    apps.activate(Apps.finder)
    #expect(backs == 1)
  }

  @Test func aPromptAlreadyUpWhenTheReadStartsIsWaitedOn() {
    let apps = Apps()
    apps.front = Apps.finder
    apps.activate(Apps.folderPrompt)
    var backs = 0
    var others = 0
    let done = apps.returns.watchRead(back: { backs += 1 }, otherwise: { others += 1 })
    done()
    #expect(backs == 0)
    apps.answerFolderPrompt()
    #expect(backs == 1)
    #expect(others == 0)
  }

  @Test func theWindowComesBackWhenTheAccessibilityAlertIsDenied() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.askedForAccessibility()
    apps.activate(Apps.accessibilityAlert)
    #expect(backs == 0)
    apps.close(Apps.accessibilityAlert)
    apps.activate(Apps.finder)
    #expect(backs == 1)
  }

  @Test func theWindowComesBackWhenFinderActivatesBeforeTheDeniedAlertWindowLeaves() async {
    let apps = Apps()
    let outcomes = Outcomes()
    let hooks = apps.returns.hooks { outcomes.backs += 1 }
    hooks.askedForAccessibility()
    apps.activate(Apps.accessibilityAlert)
    apps.activate(Apps.finder)
    #expect(outcomes.backs == 0)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.waits == 1 })
    apps.close(Apps.accessibilityAlert)
    await apps.runChecks(after: 1)
    #expect(outcomes.backs == 1)
  }

  @Test func openSystemSettingsFromTheAlertWithSystemSettingsAlreadyRunningLeavesItTheFront()
    async
  {
    let apps = Apps()
    let outcomes = Outcomes()
    let hooks = apps.returns.hooks { outcomes.backs += 1 }
    hooks.askedForAccessibility()
    apps.activate(Apps.accessibilityAlert)
    apps.activate(Apps.finder)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.waits == 1 })
    apps.close(Apps.accessibilityAlert)
    apps.activate(Apps.settings)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.cancels == 1 })
    await apps.runChecks(after: 1)
    #expect(outcomes.backs == 0)
    apps.quitSettings(fallbackFirst: true)
    #expect(outcomes.backs == 1)
  }

  @Test(arguments: [true, false])
  func openSystemSettingsFromTheAlertWhileSystemSettingsLaunchesLeavesItTheFrontUntilItQuits(
    _ fallbackFirst: Bool
  ) async {
    let apps = Apps()
    let outcomes = Outcomes()
    let hooks = apps.returns.hooks { outcomes.backs += 1 }
    hooks.askedForAccessibility()
    apps.activate(Apps.accessibilityAlert)
    apps.activate(Apps.finder)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.waits == 1 })
    apps.settingsLaunched = true
    apps.close(Apps.accessibilityAlert)
    await apps.runChecks(after: 1)
    #expect(outcomes.backs == 0)
    apps.activate(Apps.settings)
    #expect(outcomes.backs == 0)
    apps.quitSettings(fallbackFirst: fallbackFirst)
    #expect(outcomes.backs == 1)
  }

  @Test(arguments: [true, false])
  func systemSettingsThatRegistersAfterTheCheckStillBringsTheWindowBackWhenItQuits(
    _ fallbackFirst: Bool
  ) async {
    let apps = Apps()
    let outcomes = Outcomes()
    let hooks = apps.returns.hooks { outcomes.backs += 1 }
    hooks.askedForAccessibility()
    apps.activate(Apps.accessibilityAlert)
    apps.activate(Apps.finder)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.waits == 1 })
    apps.close(Apps.accessibilityAlert)
    await apps.runChecks(after: 1)
    #expect(outcomes.backs == 1)
    apps.settingsLaunched = true
    apps.activate(Apps.settings)
    #expect(outcomes.backs == 1)
    apps.quitSettings(fallbackFirst: fallbackFirst)
    #expect(outcomes.backs == 2)
  }

  @Test func aDeniedAccessibilityAlertKeepsTheSystemSettingsReturnArmed() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.askedForAccessibility()
    apps.activate(Apps.accessibilityAlert)
    apps.close(Apps.accessibilityAlert)
    apps.activate(Apps.finder)
    #expect(backs == 1)
    apps.activate(Apps.settings)
    #expect(backs == 1)
    apps.quitSettings(fallbackFirst: true)
    #expect(backs == 2)
  }

  @Test(arguments: [true, false])
  func theAccessibilityAlertLeavesTheFrontToSystemSettingsWhenItOpensThem(_ fallbackFirst: Bool) {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.askedForAccessibility()
    apps.activate(Apps.accessibilityAlert)
    apps.close(Apps.accessibilityAlert)
    if fallbackFirst {
      apps.settingsLaunched = true
      apps.activate(Apps.finder)
    }
    apps.activate(Apps.settings)
    #expect(backs == 0)
    apps.quitSettings(fallbackFirst: true)
    #expect(backs == 1)
  }

  @Test func choosingAnotherAppWhileTheAccessibilityAlertIsUpLeavesTheFrontAlone() async {
    let apps = Apps()
    let outcomes = Outcomes()
    let hooks = apps.returns.hooks { outcomes.backs += 1 }
    hooks.askedForAccessibility()
    apps.activate(Apps.accessibilityAlert)
    apps.activate(Apps.editor)
    await apps.runChecks(after: 1)
    apps.close(Apps.accessibilityAlert)
    apps.activate(Apps.finder)
    #expect(outcomes.backs == 0)
  }

  @Test func theWorkspaceNotificationNamesTheAppThatChanged() {
    let note = Notification(
      name: NSWorkspace.didActivateApplicationNotification, object: nil,
      userInfo: [NSWorkspace.applicationUserInfoKey: NSRunningApplication.current])
    #expect(FrontReturn.app(in: note)?.pid == ProcessInfo.processInfo.processIdentifier)
    #expect(
      FrontReturn.app(in: Notification(name: NSWorkspace.didActivateApplicationNotification))
        == nil)
    #expect(!FrontReturn.showsWindow(pid: -1))
  }
}

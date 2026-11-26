import AppKit
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct FrontReturnTests {
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

    lazy var returns = FrontReturn(
      center: center, ownBundleID: Apps.own.bundleID,
      frontmost: { [unowned self] in front },
      app: { $0.userInfo?["app"] as? AppSnapshot },
      showsWindow: { [unowned self] in windows.contains($0) },
      settingsLaunched: { [unowned self] _ in settingsLaunched })

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

  @Test func choosingAnotherAppWhileTheFolderPromptIsUpLeavesTheFrontAlone() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    let done = hooks.read()
    apps.activate(Apps.folderPrompt)
    apps.activate(Apps.editor)
    apps.close(Apps.folderPrompt)
    done()
    apps.activate(Apps.finder)
    #expect(backs == 0)
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

  @Test func aDeniedAccessibilityAlertLeavesNothingWaitingOnSystemSettings() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.askedForAccessibility()
    apps.activate(Apps.accessibilityAlert)
    apps.close(Apps.accessibilityAlert)
    apps.activate(Apps.finder)
    #expect(backs == 1)
    apps.activate(Apps.settings)
    apps.quitSettings(fallbackFirst: true)
    #expect(backs == 1)
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

  @Test func choosingAnotherAppWhileTheAccessibilityAlertIsUpLeavesTheFrontAlone() {
    let apps = Apps()
    var backs = 0
    let hooks = apps.returns.hooks { backs += 1 }
    hooks.askedForAccessibility()
    apps.activate(Apps.accessibilityAlert)
    apps.activate(Apps.editor)
    apps.close(Apps.accessibilityAlert)
    apps.activate(Apps.finder)
    #expect(backs == 0)
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

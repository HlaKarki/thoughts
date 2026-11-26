import AppKit
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct WindowFrontTests {
  @MainActor
  final class Fronting {
    var events: [String] = []
    var windows: [NSWindow] = []
    var shown = true
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
        orderFrontRegardless: { _ in self.events.append("order front regardless") },
        isShown: { _ in self.shown })
    }
  }

  typealias Apps = FrontReturnTests.Apps

  @MainActor
  final class Returning {
    let fronting = Fronting()
    let apps = Apps()
    let system = FakeSystem()
    let login = FakeLogin()
    private var controllers: [AnyObject] = []

    var events: [String] { fronting.events }

    func firstRun(mover: StorageMover = SettingsFixtures.mover()) throws -> FirstRunModel {
      let preferences = try SettingsFixtures.preferences()
      var made: FirstRunModel?
      let controller = FirstRunWindowController(front: fronting.front, returns: apps.returns) {
        [system] in
        let model = try! SettingsFixtures.firstRun(
          system: system, preferences: preferences, mover: mover)
        made = model
        return model
      }
      controller.show()
      controllers.append(controller)
      return try #require(made)
    }

    func settings(mover: StorageMover = SettingsFixtures.mover()) throws -> SettingsModel {
      let preferences = try SettingsFixtures.preferences()
      var made: SettingsModel?
      let controller = SettingsWindowController(front: fronting.front, returns: apps.returns) {
        [system, login] in
        let model = try! SettingsFixtures.settings(
          system: system, preferences: preferences, login: login, mover: mover)
        made = model
        return model
      }
      controller.show()
      controllers.append(controller)
      return try #require(made)
    }
  }

  static func holdingMover(_ hold: Hold) -> StorageMover {
    let folder = SettingsFixtures.home.appendingPathComponent("Thoughts", isDirectory: true)
    return StorageMover(
      current: { folder }, stop: {}, apply: { _ in hold.pass() }, relocate: { _ in },
      restart: {})
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

  @Test func theFirstRunWindowComesBackWhenSystemSettingsQuitsAfterTheGrant() async throws {
    let rig = Returning()
    let model = try rig.firstRun()
    model.openAccessibility()
    rig.apps.activate(Apps.accessibilityAlert)
    rig.apps.close(Apps.accessibilityAlert)
    rig.apps.activate(Apps.settings)
    #expect(rig.events == Self.fromBehindAnotherApp)
    let watching = Task { await model.watchAccessibility() }
    rig.system.trusted = true
    await watching.value
    #expect(rig.events == Self.fromBehindAnotherApp + Self.again)
    rig.apps.activate(Apps.own)
    rig.apps.activate(Apps.settings)
    rig.apps.quitSettings(fallbackFirst: true)
    #expect(rig.events == Self.fromBehindAnotherApp + Self.again + Self.again)
    #expect(rig.fronting.windows.count == 3)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func theFirstRunWindowIsBroughtOnceWhenSystemSettingsQuitsRightAfterTheGrant()
    async throws
  {
    let rig = Returning()
    let model = try rig.firstRun()
    model.openAccessibility()
    rig.apps.activate(Apps.accessibilityAlert)
    rig.apps.close(Apps.accessibilityAlert)
    rig.apps.activate(Apps.settings)
    let watching = Task { await model.watchAccessibility() }
    rig.system.trusted = true
    await watching.value
    rig.apps.activate(Apps.own)
    rig.apps.terminate(Apps.settings)
    #expect(rig.events == Self.fromBehindAnotherApp + Self.again)
  }

  @Test func theFirstRunWindowComesBackWhenSystemSettingsOpenedAgainQuits() throws {
    let rig = Returning()
    let model = try rig.firstRun()
    model.openAccessibility()
    rig.apps.activate(Apps.accessibilityAlert)
    rig.apps.close(Apps.accessibilityAlert)
    rig.apps.activate(Apps.settings)
    rig.apps.quitSettings(fallbackFirst: false)
    #expect(rig.events == Self.fromBehindAnotherApp + Self.again)
    rig.apps.activate(Apps.own)
    model.openAccessibility()
    #expect(rig.system.opened == [SystemServices.accessibilityPane])
    rig.apps.activate(Apps.settings)
    rig.apps.quitSettings(fallbackFirst: true)
    #expect(rig.events == Self.fromBehindAnotherApp + Self.again + Self.again)
  }

  @Test func theFirstRunWindowStaysBehindAnAppThePersonChoseBeforeSystemSettingsQuit() throws {
    let rig = Returning()
    let model = try rig.firstRun()
    model.openAccessibility()
    rig.apps.activate(Apps.accessibilityAlert)
    rig.apps.close(Apps.accessibilityAlert)
    rig.apps.activate(Apps.settings)
    rig.apps.activate(Apps.editor)
    rig.apps.close(Apps.settings)
    rig.apps.terminate(Apps.settings)
    #expect(rig.events == Self.fromBehindAnotherApp)
  }

  @Test func theFirstRunWindowComesBackWhenTheAccessibilityAlertIsDenied() throws {
    let rig = Returning()
    let model = try rig.firstRun()
    model.openAccessibility()
    #expect(rig.system.requested == 1)
    rig.apps.activate(Apps.accessibilityAlert)
    rig.apps.close(Apps.accessibilityAlert)
    rig.apps.activate(Apps.finder)
    #expect(rig.events == Self.fromBehindAnotherApp + Self.again)
  }

  @Test(arguments: [true, false])
  func stepFiveComesBackAfterTheDesktopFolderPrompt(_ readFirst: Bool) async throws {
    let rig = Returning()
    rig.system.trusted = true
    rig.system.folderReads.holdEachRead()
    defer { rig.system.folderReads.releaseHeldReads() }
    let model = try rig.firstRun()
    for _ in 0..<4 { model.advance() }
    #expect(model.step == .clipboard)
    let reading = Task { await model.readWatchedFolders() }
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { !rig.system.read.isEmpty })
    rig.apps.activate(Apps.folderPrompt)
    rig.apps.close(Apps.folderPrompt)
    let returned = Self.fromBehindAnotherApp + Self.again
    if readFirst {
      rig.system.folderReads.releaseHeldReads()
      await reading.value
      await InputFocusTests.settle()
      #expect(rig.events == Self.fromBehindAnotherApp)
      rig.apps.activate(Apps.finder)
      #expect(rig.events == returned)
    } else {
      rig.apps.activate(Apps.finder)
      #expect(rig.events == Self.fromBehindAnotherApp)
      rig.system.folderReads.releaseHeldReads()
      await reading.value
      #expect(await PanelHarness.waitUntil(within: .seconds(2)) { rig.events == returned })
    }
    await InputFocusTests.settle()
    #expect(rig.events == returned)
    #expect(rig.system.read.count == 1)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func stepFiveStaysBehindAnAppThePersonChoseWhileTheFolderPromptWasUp() async throws {
    let rig = Returning()
    rig.system.trusted = true
    rig.system.folderReads.holdEachRead()
    defer { rig.system.folderReads.releaseHeldReads() }
    let model = try rig.firstRun()
    for _ in 0..<4 { model.advance() }
    let reading = Task { await model.readWatchedFolders() }
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { !rig.system.read.isEmpty })
    rig.apps.activate(Apps.folderPrompt)
    rig.apps.activate(Apps.editor)
    rig.apps.close(Apps.folderPrompt)
    rig.system.folderReads.releaseHeldReads()
    await reading.value
    await InputFocusTests.settle()
    rig.apps.activate(Apps.finder)
    #expect(rig.events == Self.fromBehindAnotherApp)
  }

  @Test func stepFourComesBackAfterAFolderPromptDuringTheStorageChange() async throws {
    let rig = Returning()
    let hold = Hold()
    defer { hold.release() }
    let model = try rig.firstRun(mover: Self.holdingMover(hold))
    rig.system.picks = [SettingsFixtures.home.appendingPathComponent("Documents/Thoughts")]
    let changing = Task { await model.changeStorage() }
    await hold.waitForArrivals(1)
    rig.apps.activate(Apps.folderPrompt)
    rig.apps.answerFolderPrompt()
    #expect(rig.events == Self.fromBehindAnotherApp)
    hold.release()
    await changing.value
    #expect(rig.events == Self.fromBehindAnotherApp + Self.again)
  }

  @Test(arguments: [false, true])
  func theSettingsWindowComesBackWhenSystemSettingsQuits(_ loginItems: Bool) throws {
    let rig = Returning()
    let model = try rig.settings()
    if loginItems {
      model.openLoginSettings()
      #expect(rig.login.openedSettings == 1)
    } else {
      model.openClipboardSettings()
      #expect(rig.system.opened == [SystemServices.pasteboardPane])
    }
    rig.apps.activate(Apps.settings)
    #expect(rig.events == Self.fromBehindAnotherApp)
    rig.apps.quitSettings(fallbackFirst: true)
    #expect(rig.events == Self.fromBehindAnotherApp + Self.again)
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func aClosedSettingsWindowStaysClosedWhenSystemSettingsQuits() throws {
    let rig = Returning()
    let model = try rig.settings()
    model.openClipboardSettings()
    rig.apps.activate(Apps.settings)
    rig.fronting.shown = false
    rig.apps.quitSettings(fallbackFirst: true)
    #expect(rig.events == Self.fromBehindAnotherApp)
  }

  @Test func theSettingsWindowComesBackAfterAFolderPromptDuringAStorageMove() async throws {
    let rig = Returning()
    let hold = Hold()
    defer { hold.release() }
    let model = try rig.settings(mover: Self.holdingMover(hold))
    rig.system.picks = [SettingsFixtures.home.appendingPathComponent("Documents/Thoughts")]
    let moving = Task { await model.moveStorage() }
    await hold.waitForArrivals(1)
    rig.apps.activate(Apps.folderPrompt)
    rig.apps.answerFolderPrompt()
    #expect(rig.events == Self.fromBehindAnotherApp)
    hold.release()
    await moving.value
    #expect(rig.events == Self.fromBehindAnotherApp + Self.again)
  }

  @Test func theSettingsWindowComesBackAfterAFolderPromptForAnAddedWatchedFolder() async throws {
    let rig = Returning()
    rig.system.folderReads.holdEachRead()
    defer { rig.system.folderReads.releaseHeldReads() }
    let model = try rig.settings()
    let shots = SettingsFixtures.home.appendingPathComponent("Documents/Shots", isDirectory: true)
    rig.system.picks = [shots]
    let adding = Task { await model.addWatchedFolder() }
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { !rig.system.read.isEmpty })
    #expect(model.preferences.watchedFolders == [shots])
    rig.apps.activate(Apps.folderPrompt)
    rig.apps.answerFolderPrompt()
    #expect(rig.events == Self.fromBehindAnotherApp)
    rig.system.folderReads.releaseHeldReads()
    await adding.value
    #expect(rig.events == Self.fromBehindAnotherApp + Self.again)
    #expect(rig.system.read == [shots])
    #expect(!rig.system.folderReads.anyOnMain)
  }

  @Test func addingAWatchedFolderWithOffersOffReadsNothingAndBringsNothing() async throws {
    let rig = Returning()
    let model = try rig.settings()
    model.preferences.offersEnabled = false
    let shots = SettingsFixtures.home.appendingPathComponent("Documents/Shots", isDirectory: true)
    rig.system.picks = [shots]
    await model.addWatchedFolder()
    #expect(model.preferences.watchedFolders == [shots])
    #expect(rig.system.read.isEmpty)
    rig.apps.activate(Apps.finder)
    #expect(rig.events == Self.fromBehindAnotherApp)
  }
}

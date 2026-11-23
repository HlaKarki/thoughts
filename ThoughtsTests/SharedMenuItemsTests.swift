import Testing

@testable import Thoughts

@MainActor
struct SharedMenuItemsTests {
  @MainActor
  final class Calls {
    var settings = 0
    var updates = 0
    var quits = 0
  }

  static func make(
    calls: Calls = Calls(), updates: UpdateMenuItem = UpdateMenuItem(), wired: Bool = true
  ) -> SharedMenuItems {
    var openSettings: (@MainActor () -> Void)?
    var checkForUpdates: (@MainActor () -> Void)?
    if wired {
      openSettings = { calls.settings += 1 }
      checkForUpdates = { calls.updates += 1 }
    }
    return SharedMenuItems(
      updates: updates, openSettings: openSettings, checkForUpdates: checkForUpdates,
      quit: { calls.quits += 1 })
  }

  @Test func theItemsCarryTheirTitlesAndRunTheirActions() {
    let calls = Calls()
    let updates = UpdateMenuItem()
    updates.updateWillShow(handledBySparkle: false)
    let shared = Self.make(calls: calls, updates: updates)
    let titles = [shared.updateAvailable, shared.settings, shared.checkForUpdates, shared.quit]
      .compactMap { $0?.title }
    #expect(titles == ["Update available", "Settings…", "Check for updates…", "Quit Thoughts"])
    shared.updateAvailable?.perform()
    shared.settings.perform()
    shared.checkForUpdates.perform()
    shared.quit.perform()
    #expect(calls.updates == 2)
    #expect(calls.settings == 1)
    #expect(calls.quits == 1)
  }

  @Test func theUpdateItemFollowsTheUpdateSession() {
    let updates = UpdateMenuItem()
    let shared = Self.make(updates: updates)
    #expect(shared.updateAvailable == nil)
    updates.updateWillShow(handledBySparkle: false)
    #expect(shared.updateAvailable?.id == .updateAvailable)
    updates.sessionWillFinish()
    #expect(shared.updateAvailable == nil)
  }

  @Test func anItemWithNoActionIsDisabledAndQuitStaysEnabled() {
    let shared = Self.make(wired: false)
    #expect(!shared.settings.isEnabled)
    #expect(!shared.checkForUpdates.isEnabled)
    #expect(shared.quit.isEnabled)
  }
}

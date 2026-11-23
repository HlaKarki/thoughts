import AppKit
import Testing

@testable import Thoughts

@MainActor
struct MenuBarControllerTests {
  final class FakeSurface: StatusItemSurface {
    var isVisible = true
    var onRemoved: (@MainActor () -> Void)?
    var screen: NSScreen? = NSScreen.screens.first
    private(set) var presented: [(updateWaiting: Bool, label: String)] = []

    func present(updateWaiting: Bool, label: String) {
      presented.append((updateWaiting, label))
    }

    func removeByDrag() {
      isVisible = false
      onRemoved?()
    }
  }

  @MainActor
  final class Rig {
    let defaults: UserDefaults
    let preferences: Preferences
    let updates = UpdateMenuItem()
    let surface = FakeSurface()
    let controller: MenuBarController

    init() throws {
      let name = "thoughts.tests.\(UUID().uuidString)"
      defaults = try #require(UserDefaults(suiteName: name))
      defaults.removePersistentDomain(forName: name)
      preferences = Preferences(defaults: defaults)
      let shared = SharedMenuItems(updates: updates, openSettings: {}, checkForUpdates: {})
      let bar = MenuBarMenu(shared: shared, setSummonEnabled: { _, _ in })
      let box = ScreenBox()
      screens = box
      menu = bar
      controller = MenuBarController(
        preferences: preferences, updates: updates, surface: surface, menu: bar,
        showPanel: { box.values.append($0) })
    }

    let menu: MenuBarMenu
    let screens: ScreenBox
  }

  final class ScreenBox {
    var values: [NSScreen?] = []
  }

  @Test func theIconIsShownAtFirstLaunch() throws {
    let rig = try Rig()
    rig.surface.isVisible = false
    rig.controller.start()
    #expect(rig.surface.isVisible)
  }

  @Test func turningTheSettingOffRemovesTheIconAndOnBringsItBack() async throws {
    let rig = try Rig()
    rig.controller.start()
    rig.preferences.showsMenuBarIcon = false
    await MenuBarMenuTests.waitUntil { !rig.surface.isVisible }
    #expect(!rig.surface.isVisible)
    rig.preferences.showsMenuBarIcon = true
    await MenuBarMenuTests.waitUntil { rig.surface.isVisible }
    #expect(rig.surface.isVisible)
  }

  @Test func aSavedOffSettingKeepsTheIconHiddenFromTheStart() throws {
    let rig = try Rig()
    rig.preferences.showsMenuBarIcon = false
    rig.controller.start()
    #expect(!rig.surface.isVisible)
  }

  @Test func removingTheIconByDragTurnsTheSettingOffAndTheSettingBringsItBack() async throws {
    let rig = try Rig()
    rig.controller.start()
    rig.surface.removeByDrag()
    #expect(!rig.preferences.showsMenuBarIcon)
    #expect(!Preferences(defaults: rig.defaults).showsMenuBarIcon)
    await MenuBarMenuTests.waitUntil { !rig.surface.isVisible }
    #expect(!rig.surface.isVisible)
    rig.preferences.showsMenuBarIcon = true
    await MenuBarMenuTests.waitUntil { rig.surface.isVisible }
    #expect(rig.surface.isVisible)
  }

  @Test func theDotAndTheLabelFollowTheUpdateSession() async throws {
    let rig = try Rig()
    rig.controller.start()
    #expect(rig.surface.presented.last?.updateWaiting == false)
    #expect(rig.surface.presented.last?.label == "Thoughts")
    rig.updates.updateWillShow(handledBySparkle: false)
    await MenuBarMenuTests.waitUntil { rig.surface.presented.last?.updateWaiting == true }
    #expect(rig.surface.presented.last?.updateWaiting == true)
    #expect(rig.surface.presented.last?.label == "Thoughts, update available")
    rig.updates.sessionWillFinish()
    await MenuBarMenuTests.waitUntil { rig.surface.presented.last?.updateWaiting == false }
    #expect(rig.surface.presented.last?.updateWaiting == false)
    #expect(rig.surface.presented.last?.label == "Thoughts")
  }

  @Test func showThoughtsPassesTheScreenOfTheClickedMenuBar() throws {
    let rig = try Rig()
    rig.controller.start()
    rig.menu.menu.performActionForItem(at: 0)
    #expect(rig.screens.values.count == 1)
    #expect(rig.screens.values.first.flatMap { $0 } === rig.surface.screen)
  }

  @Test func stoppingLeavesTheSettingAloneWhenTheIconGoes() throws {
    let rig = try Rig()
    rig.controller.start()
    rig.controller.stop()
    rig.surface.removeByDrag()
    #expect(rig.preferences.showsMenuBarIcon)
  }
}

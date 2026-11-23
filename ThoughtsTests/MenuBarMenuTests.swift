import AppKit
import KeyboardShortcuts
import Testing

@testable import Thoughts

@MainActor
struct MenuBarMenuTests {
  @MainActor
  final class Log {
    var events: [String] = []
    var summon: [(name: KeyboardShortcuts.Name, enabled: Bool)] = []
  }

  @MainActor
  final class Rig {
    let updates = UpdateMenuItem()
    let log = Log()
    let shared: SharedMenuItems
    let menuBar: MenuBarMenu
    let name = KeyboardShortcuts.Name("thoughts.tests.\(UUID().uuidString)")

    init(wired: Bool = true) {
      let log = log
      var openSettings: (@MainActor () -> Void)?
      var checkForUpdates: (@MainActor () -> Void)?
      if wired {
        openSettings = { log.events.append("settings") }
        checkForUpdates = { log.events.append("updates") }
      }
      shared = SharedMenuItems(
        updates: updates, openSettings: openSettings, checkForUpdates: checkForUpdates,
        quit: { log.events.append("quit") })
      menuBar = MenuBarMenu(
        shared: shared, summon: name, setSummonEnabled: { log.summon.append(($0, $1)) })
      menuBar.onShow = { log.events.append("show") }
    }

    deinit {
      let name = name
      MainActor.assumeIsolated { KeyboardShortcuts.reset(name) }
    }
  }

  static func layout(_ menu: NSMenu) -> [String] {
    menu.items.map { $0.isSeparatorItem ? "-" : $0.title }
  }

  static func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<500 where !condition() {
      try? await Task.sleep(for: .milliseconds(2))
    }
  }

  @Test func theMenuListsItsItemsInOrderWithAndWithoutAnUpdate() {
    let rig = Rig()
    #expect(
      Self.layout(rig.menuBar.menu) == [
        "Show Thoughts", "-", "Settings…", "Check for updates…", "-", "Quit Thoughts",
      ])
    rig.updates.updateWillShow(handledBySparkle: false)
    rig.menuBar.menuNeedsUpdate(rig.menuBar.menu)
    #expect(
      Self.layout(rig.menuBar.menu) == [
        "Show Thoughts", "-", "Update available", "Settings…", "Check for updates…", "-",
        "Quit Thoughts",
      ])
    rig.updates.sessionWillFinish()
    rig.menuBar.menuNeedsUpdate(rig.menuBar.menu)
    #expect(rig.menuBar.menu.items.count == 6)
  }

  @Test func thePanelOnlyItemsStayOutOfTheMenuBarMenu() {
    let titles = Self.layout(Rig().menuBar.menu)
    #expect(!titles.contains("Keep open"))
    #expect(!titles.contains("Clear done"))
  }

  @Test func eachItemRunsTheSharedActionAndShowRunsTheShowPath() {
    let rig = Rig()
    rig.updates.updateWillShow(handledBySparkle: false)
    rig.menuBar.menuNeedsUpdate(rig.menuBar.menu)
    let menu = rig.menuBar.menu
    for index in [0, 2, 3, 4, 6] { menu.performActionForItem(at: index) }
    #expect(rig.log.events == ["show", "updates", "settings", "updates", "quit"])
  }

  @Test func theTitlesAndEnabledStateComeFromTheSharedDefinitionForBothMenus() throws {
    let rig = Rig(wired: false)
    rig.updates.updateWillShow(handledBySparkle: false)
    rig.menuBar.menuNeedsUpdate(rig.menuBar.menu)
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let more = MoreMenu(preferences: Preferences(defaults: defaults), shared: rig.shared)
    #expect(more.shared === rig.shared)
    for id in SharedMenuItem.ID.allCases {
      let definition = rig.shared.item(id)
      let item = try #require(
        rig.menuBar.menu.items.first { $0.identifier?.rawValue == id.rawValue })
      #expect(item.title == definition.title)
      #expect(item.isEnabled == definition.isEnabled)
    }
    #expect(more.shared.updateAvailable?.title == "Update available")
    #expect(rig.menuBar.menu.item(withTitle: "Settings…")?.isEnabled == false)
    #expect(rig.menuBar.menu.item(withTitle: "Quit Thoughts")?.isEnabled == true)
  }

  @Test func showThoughtsCarriesTheSummonKeyAndFollowsAChange() async throws {
    let rig = Rig()
    let first = KeyboardShortcuts.Shortcut(.k, modifiers: [.option])
    KeyboardShortcuts.setShortcut(first, for: rig.name)
    let item = try #require(rig.menuBar.menu.items.first)
    #expect(item.title == "Show Thoughts")
    await Self.waitUntil { item.keyEquivalent == "k" }
    #expect(item.keyEquivalent == "k")
    #expect(item.keyEquivalentModifierMask == [.option])

    KeyboardShortcuts.setShortcut(
      KeyboardShortcuts.Shortcut(.j, modifiers: [.control, .command]), for: rig.name)
    await Self.waitUntil { item.keyEquivalent == "j" }
    #expect(item.keyEquivalent == "j")
    #expect(item.keyEquivalentModifierMask == [.control, .command])

    KeyboardShortcuts.setShortcut(nil, for: rig.name)
    await Self.waitUntil { item.keyEquivalent == "" }
    #expect(item.keyEquivalent == "")
  }

  @Test func theSummonKeyIsOffWhileTheMenuIsOpenAndBackWhenItCloses() {
    let rig = Rig()
    rig.menuBar.menuWillOpen(rig.menuBar.menu)
    rig.menuBar.menuDidClose(rig.menuBar.menu)
    #expect(rig.log.summon.map(\.enabled) == [false, true])
    #expect(rig.log.summon.allSatisfy { $0.name == rig.name })
  }
}

import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

final class OffscreenWindow: NSPanel {
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }

  override var canBecomeKey: Bool { true }
}

@MainActor
final class CloseAsks: NSObject, NSWindowDelegate {
  var asks = 0

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    asks += 1
    return false
  }
}

@MainActor
final class MenuTally: NSObject {
  var hides = 0
  var hidesOthers = 0
  var showsAll = 0
  @objc func hide(_ sender: Any?) { hides += 1 }
  @objc func hideOthers(_ sender: Any?) { hidesOthers += 1 }
  @objc func showAll(_ sender: Any?) { showsAll += 1 }

  var total: Int { hides + hidesOthers + showsAll }
}

@MainActor
@Suite(.serialized, .throwaway)
struct StandardKeysTests {
  @MainActor
  final class Rig {
    let menu: AppMenu
    let settings = Tally()
    let quits = Tally()
    let hide = MenuTally()
    private let previous = NSApp.mainMenu
    private let previousWindows = NSApp.windowsMenu

    init() {
      let settings = settings
      let quits = quits
      let shared = SharedMenuItems(
        updates: UpdateMenuItem(), openSettings: { settings.count += 1 },
        checkForUpdates: nil, quit: { quits.count += 1 })
      menu = AppMenu(shared: shared, appName: "Thoughts")
      menu.install()
      let rewired: [String: Selector] = [
        NSStringFromSelector(#selector(NSApplication.hide(_:))): #selector(MenuTally.hide(_:)),
        NSStringFromSelector(#selector(NSApplication.hideOtherApplications(_:))):
          #selector(MenuTally.hideOthers(_:)),
        NSStringFromSelector(#selector(NSApplication.unhideAllApplications(_:))):
          #selector(MenuTally.showAll(_:)),
      ]
      for item in menu.menu.items.compactMap(\.submenu).flatMap(\.items) {
        guard let action = item.action, let replacement = rewired[NSStringFromSelector(action)]
        else { continue }
        item.target = hide
        item.action = replacement
      }
    }

    var itemsAimedAtTheHost: [String] {
      let dangerous = [
        #selector(NSApplication.hide(_:)), #selector(NSApplication.hideOtherApplications(_:)),
        #selector(NSApplication.unhideAllApplications(_:)), #selector(NSApplication.terminate(_:)),
      ].map(NSStringFromSelector)
      return menu.menu.items.compactMap(\.submenu).flatMap(\.items).filter {
        $0.target === NSApp
          && $0.action.map { dangerous.contains(NSStringFromSelector($0)) } == true
      }.map(\.title)
    }

    func restore() {
      NSApp.mainMenu = previous
      NSApp.windowsMenu = previousWindows
    }
  }

  static func window(_ style: NSWindow.StyleMask, field: NSTextField? = nil) -> OffscreenWindow {
    let window = OffscreenWindow(
      contentRect: CGRect(x: 0, y: 0, width: 300, height: 120),
      styleMask: style.union(.nonactivatingPanel),
      backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    let union = NSScreen.screens.map(\.frame).reduce(CGRect.null) { $0.union($1) }
    window.setFrameOrigin(CGPoint(x: union.maxX + 4000, y: union.minY))
    if let field {
      field.frame = CGRect(x: 10, y: 40, width: 280, height: 24)
      window.contentView?.addSubview(field)
    }
    window.orderFrontRegardless()
    return window
  }

  static func menuItem(_ menu: NSMenu, _ title: String) -> NSMenuItem? {
    menu.items.compactMap(\.submenu).flatMap(\.items).first { $0.title == title }
  }

  @Test func commandCommaAsksForSettingsFromEveryFocusOfThePanel() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["first", "second"])
      try await harness.show()
      var asked = 0
      @MainActor func press() async {
        await harness.press(.character(","), .command)
        asked += 1
        #expect(harness.settingsRequests == asked, "\(harness.list.focus) did not ask once")
      }
      await press()
      #expect(harness.list.focus == .input)
      await harness.press(.up)
      #expect(harness.list.focus == .list)
      await press()
      #expect(harness.list.focus == .list)
      await harness.press(.character("f"), .command)
      #expect(harness.list.focus == .search)
      await press()
      #expect(harness.list.focus == .search)
      #expect(harness.input.text.isEmpty)
      #expect(harness.list.query.isEmpty)
      #expect(harness.hideRequests == 0)
      #expect(harness.foreignKeys == 0)
    }
  }

  @Test func commandCommaAsksForSettingsWhileAThoughtIsPreviewed() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["first"])
      try await harness.show()
      await harness.press(.up)
      await harness.press(.space)
      #expect(harness.list.isPreviewing)
      await harness.press(.character(","), .command)
      #expect(harness.settingsRequests == 1)
      #expect(harness.list.isPreviewing)
      #expect(harness.hideRequests == 0)
    }
  }

  @Test func theKeysThatBelongToTheAppInFrontDoNothingInThePanel() async throws {
    let rig = Rig()
    defer { rig.restore() }
    try await PanelHarness.run { harness in
      try harness.seed(["first"])
      try await harness.show()
      for key in ["q", "h", "m", "w"] {
        for flags: NSEvent.ModifierFlags in [.command, [.command, .option], [.command, .shift]] {
          await harness.press(.character(Character(key)), flags)
        }
      }
      #expect(rig.quits.count == 0)
      #expect(rig.hide.total == 0)
      #expect(rig.settings.count == 0)
      #expect(harness.settingsRequests == 0)
      #expect(harness.hideRequests == 0)
      #expect(harness.panel.isVisible)
      #expect(harness.input.text.isEmpty)
    }
  }

  @Test func noMenuItemCanHideOrQuitTheTestHost() {
    let rig = Rig()
    defer { rig.restore() }
    #expect(rig.itemsAimedAtTheHost.isEmpty)
    let titles = rig.menu.menu.items.compactMap(\.submenu).flatMap(\.items).map(\.title)
    #expect(titles.contains("Hide Others"))
    #expect(titles.contains("Show All"))
  }

  @Test(arguments: [false, true])
  func everyPanelKeyDoesTheSameWithTheMenuInstalled(_ installed: Bool) async throws {
    let rig = installed ? Rig() : nil
    defer { rig?.restore() }
    #expect(NSApp.mainMenu === rig?.menu.menu)
    try await PanelHarness.run { harness in
      let page = try #require(URL(string: "https://example.com/page"))
      try harness.fixture.addText("older", daysAgo: 3)
      let middle = try harness.fixture.addText(
        "middle", daysAgo: 2, source: Source(bundleID: "com.example.browser", url: page))
      let newest = try harness.fixture.addText("newest", daysAgo: 1)
      try harness.fixture.reload()
      try await harness.show()
      let list = harness.list
      await harness.press(.up)
      #expect(list.selection == [newest.file.lastPathComponent])
      #expect(list.focus == .list)
      await harness.press(.up)
      #expect(list.selection == [middle.file.lastPathComponent])
      await harness.press(.down)
      await harness.press(.up)
      #expect(list.selection == [middle.file.lastPathComponent])

      await harness.press(.character("k"), .command)
      #expect(list.isMenuOpen)
      await harness.press(.character("k"), .command)
      #expect(!list.isMenuOpen)
      #expect(list.focus == .list)

      await harness.press(.character("c"), .command)
      #expect(harness.board.string(forType: .string) == "middle")
      await harness.press(.character("C"), [.command, .shift])
      #expect(harness.board.string(forType: .string) == middle.file.path)
      await harness.press(.character("o"), .command)
      #expect(harness.opener.urls == [page])
      await harness.press(.character("r"), .command)
      #expect(harness.opener.revealed == [[middle.file]])

      await harness.press(.returnKey, .command)
      await harness.actions.pending?.value
      let stored = try harness.fixture.store.entries().compactMap(\.thought)
      #expect(stored.first { $0.id == middle.id }?.done != nil)

      await harness.press(.space)
      #expect(list.isPreviewing)
      await harness.press(.escape)
      #expect(!list.isPreviewing)
      #expect(list.focus == .list)

      await harness.press(.character("f"), .command)
      #expect(list.focus == .search)
      await harness.press(.escape)
      #expect(list.focus != .search)

      await harness.press(.up)
      #expect(list.selection.count == 1)
      await harness.press(.delete, .command)
      await harness.actions.pending?.value
      #expect(try harness.storedTexts.count == 2)
      await harness.press(.character("z"), .command)
      await harness.actions.pending?.value
      #expect(try harness.storedTexts.sorted() == ["middle", "newest", "older"])

      #expect(harness.settingsRequests == 0)
      #expect(harness.hideRequests == 0)
      #expect(harness.foreignKeys == 0)
      if let rig {
        #expect(rig.quits.count == 0)
        #expect(rig.settings.count == 0)
        #expect(rig.hide.total == 0)
      }
    }
  }

  @Test func theMenuKeysReachAWindowThatIsKeyWhileTheAppIsNotActive() async throws {
    let rig = Rig()
    defer { rig.restore() }
    try await PanelHarness.run { harness in
      try await harness.show()
      let window = Self.window(SettingsWindowController.styleMask)
      let closing = CloseAsks()
      window.delegate = closing
      try harness.route(keysTo: window)
      #expect(!NSApp.isActive)
      await harness.press(.character(","), .command)
      #expect(rig.settings.count == 1)
      await harness.press(.character("q"), .command)
      #expect(rig.quits.count == 1)
      await harness.press(.character("w"), .command)
      #expect(closing.asks == 1)
      #expect(harness.settingsRequests == 0)
      try harness.routeKeysToThePanel()
      window.orderOut(nil)
    }
  }

  @Test func theWindowsDecideWhatCloseAndMinimizeDo() async throws {
    let rig = Rig()
    defer { rig.restore() }
    try await PanelHarness.run { harness in
      try await harness.show()
      let close = try #require(Self.menuItem(rig.menu.menu, "Close"))
      let minimize = try #require(Self.menuItem(rig.menu.menu, "Minimize"))
      let settings = Self.window(SettingsWindowController.styleMask)
      let firstRun = Self.window(FirstRunWindowController.styleMask)
      #expect(!harness.panel.validateMenuItem(close))
      #expect(!harness.panel.validateMenuItem(minimize))
      #expect(settings.validateMenuItem(close))
      #expect(settings.validateMenuItem(minimize))
      #expect(firstRun.validateMenuItem(close))
      #expect(!firstRun.validateMenuItem(minimize))
      settings.orderOut(nil)
      firstRun.orderOut(nil)
    }
  }

  @Test func theEditKeysWorkInATextFieldOfAnotherWindow() async throws {
    let rig = Rig()
    defer { rig.restore() }
    try await PanelHarness.run { harness in
      try await harness.show()
      let field = NSTextField(string: "")
      let window = Self.window(SettingsWindowController.styleMask, field: field)
      try harness.route(keysTo: window)
      #expect(window.makeFirstResponder(field))
      let editor = try #require(field.currentEditor() as? NSTextView)
      editor.insertText("staging key", replacementRange: editor.selectedRange())
      editor.setSelectedRange(NSRange(location: 0, length: 0))
      await harness.press(.character("a"), .command)
      #expect(editor.selectedRange() == NSRange(location: 0, length: 11))
      await harness.press(.character("z"), .command)
      #expect(editor.string.isEmpty)
      await harness.press(.character("Z"), [.command, .shift])
      #expect(editor.string == "staging key")
      window.makeFirstResponder(nil)
      try harness.routeKeysToThePanel()
      window.orderOut(nil)
    }
  }

  @Test func theMenuHasTheStandardKeysAndEditItems() {
    let rig = Rig()
    defer { rig.restore() }
    @MainActor func keys(_ title: String) -> String? {
      guard let item = Self.menuItem(rig.menu.menu, title) else { return nil }
      let shift = item.keyEquivalentModifierMask.contains(.shift) ? "shift " : ""
      let option = item.keyEquivalentModifierMask.contains(.option) ? "option " : ""
      return "\(shift)\(option)\(item.keyEquivalent)"
    }
    #expect(keys("Settings…") == ",")
    #expect(keys("Quit Thoughts") == "q")
    #expect(keys("Hide Thoughts") == "h")
    #expect(keys("Hide Others") == "option h")
    #expect(keys("Minimize") == "m")
    #expect(keys("Close") == "w")
    #expect(keys("Undo") == "z")
    #expect(keys("Redo") == "shift Z")
    #expect(keys("Cut") == "x")
    #expect(keys("Copy") == "c")
    #expect(keys("Paste") == "v")
    #expect(keys("Select All") == "a")
    #expect(NSApp.windowsMenu === rig.menu.menu.items.last?.submenu)
  }

  @Test func thePanelClaimsOnlyTheKeysThatBelongToTheFrontAppAndComma() throws {
    @MainActor func standard(_ key: String, _ flags: NSEvent.ModifierFlags) throws -> StandardKey? {
      ThoughtsPanel.standardKey(
        for: try PanelKeyEquivalentTests.event(key, flags, code: 0, window: 0))
    }
    #expect(try standard(",", .command) == .openSettings)
    #expect(try standard(",", [.command, .shift]) == nil)
    #expect(try standard(",", []) == nil)
    for key in ["q", "h", "m", "w"] {
      #expect(try standard(key, .command) == .belongsToFrontApp)
      #expect(try standard(key, [.command, .option]) == .belongsToFrontApp)
      #expect(try standard(key, []) == nil)
      #expect(try standard(key, .control) == nil)
    }
    for key in ["k", "f", "c", "o", "r", "v", "x", "a", "z", "n", "p", "t", "s", "l"] {
      #expect(try standard(key, .command) == nil, "command \(key) belongs to the panel")
    }
    #expect(try standard("c", [.command, .shift]) == nil)
    #expect(try standard("z", [.command, .shift]) == nil)
  }
}

import AppKit
import SwiftUI
import Testing

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
  @objc func hide(_ sender: Any?) { hides += 1 }
}

@MainActor
@Suite(.serialized)
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
      let hideItem = menu.menu.items[0].submenu?.items.first {
        $0.keyEquivalent == "h" && $0.keyEquivalentModifierMask == .command
      }
      hideItem?.target = hide
      hideItem?.action = #selector(MenuTally.hide(_:))
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
      #expect(rig.hide.hides == 0)
      #expect(rig.settings.count == 0)
      #expect(harness.settingsRequests == 0)
      #expect(harness.hideRequests == 0)
      #expect(harness.panel.isVisible)
      #expect(harness.input.text.isEmpty)
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

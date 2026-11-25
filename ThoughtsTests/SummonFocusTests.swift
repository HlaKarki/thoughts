import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized)
struct SummonFocusTests {
  typealias Rig = LiveEdgeTests.Rig

  static func rig(keepOpen: Bool) throws -> Rig {
    let rig = try Rig(edge: .right)
    rig.preferences.keepOpen = keepOpen
    let model = rig.fixture.model
    rig.controller.onWillShow = { model.panelWillShow() }
    rig.controller.onWillRefocus = { model.panelWillRefocus() }
    return rig
  }

  static func settled(_ rig: Rig) async {
    #expect(
      await PanelHarness.waitUntil {
        rig.controller.frame == rig.panelFrame(.right) && rig.controller.panel.alphaValue == 1
      }, "the panel never showed")
  }

  static func searching(_ rig: Rig) {
    let model = rig.fixture.model
    model.select(rig.shot.file.lastPathComponent, extend: false)
    model.query = "fetchUser"
    model.focus = .search
    #expect(!model.selection.isEmpty)
  }

  @Test func withKeepOpenTheSummonKeyFocusesAShownPanelWhereItWasAndASecondPressHidesIt()
    async throws
  {
    let rig = try Self.rig(keepOpen: true)
    let entry = PanelEntry(rig.controller)
    entry.summon()
    await Self.settled(rig)
    #expect(rig.controller.isKey)
    Self.searching(rig)
    let selection = rig.fixture.model.selection
    let other = NSWindow(
      contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
    rig.key.window = other
    #expect(!rig.controller.isKey)
    entry.summon()
    #expect(rig.controller.isShown)
    #expect(rig.controller.isKey)
    #expect(rig.key.made == 2)
    #expect(rig.fixture.model.focus == .search)
    #expect(rig.fixture.model.query == "fetchUser")
    #expect(rig.fixture.model.selection == selection)
    #expect(rig.controller.frame == rig.panelFrame(.right))
    entry.summon()
    #expect(!rig.controller.isShown)
    #expect(await PanelHarness.waitUntil { !rig.controller.isVisible })
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func withKeepOpenAFocusThatIsGoneFallsBackToAddAThought() async throws {
    let rig = try Self.rig(keepOpen: true)
    let entry = PanelEntry(rig.controller)
    entry.summon()
    await Self.settled(rig)
    rig.fixture.model.focus = .edit
    #expect(rig.fixture.model.editing == nil)
    rig.key.window = nil
    entry.summon()
    #expect(rig.controller.isKey)
    #expect(rig.fixture.model.focus == .input)
    rig.controller.hide()
    #expect(await PanelHarness.waitUntil { !rig.controller.isVisible })
  }

  @Test func withoutKeepOpenTheSummonKeyStillHidesAShownPanel() async throws {
    let rig = try Self.rig(keepOpen: false)
    let entry = PanelEntry(rig.controller)
    entry.summon()
    await Self.settled(rig)
    rig.key.window = nil
    entry.summon()
    #expect(!rig.controller.isShown)
    #expect(rig.key.made == 1)
    #expect(await PanelHarness.waitUntil { !rig.controller.isVisible })
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test(arguments: [true, false])
  func showThoughtsMakesAShownPanelKeyWithItsFocusAndNeverHidesIt(_ keepOpen: Bool)
    async throws
  {
    let rig = try Self.rig(keepOpen: keepOpen)
    let entry = PanelEntry(rig.controller)
    entry.fromMenu(on: nil)
    await Self.settled(rig)
    Self.searching(rig)
    let selection = rig.fixture.model.selection
    let other = NSWindow(
      contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
    for keyWhenOpened in [false, true] {
      rig.key.window = keyWhenOpened ? rig.controller.panel : other
      rig.controller.ownMenuOpened()
      rig.controller.ownMenuClosed(.show)
      entry.fromMenu(on: nil)
      #expect(rig.controller.isShown, "key when opened \(keyWhenOpened)")
      #expect(rig.controller.isKey, "key when opened \(keyWhenOpened)")
      #expect(rig.fixture.model.focus == .search, "key when opened \(keyWhenOpened)")
      #expect(rig.fixture.model.query == "fetchUser")
      #expect(rig.fixture.model.selection == selection)
    }
    #expect(rig.key.made == 3)
    #expect(rig.controller.frame == rig.panelFrame(.right))
    rig.controller.hide()
    #expect(await PanelHarness.waitUntil { !rig.controller.isVisible })
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }
}

import AppKit
import Testing

@testable import Thoughts

@MainActor
struct PanelEntryTests {
  @MainActor
  final class Stage {
    var shown = false
    var shows: [(screen: NSScreen?, afterMenu: Bool)] = []
    var hides = 0

    var entry: PanelEntry {
      PanelEntry(
        isShown: { self.shown },
        hide: {
          self.hides += 1
          self.shown = false
        },
        show: { screen, afterMenu in
          self.shows.append((screen, afterMenu))
          self.shown = true
        })
    }
  }

  @Test func theSummonKeyTheReopenAndTheMenuAllShowThroughOnePath() {
    let stage = Stage()
    let entry = stage.entry
    entry.summon()
    stage.shown = false
    entry.reopen()
    stage.shown = false
    entry.fromMenu(on: nil)
    #expect(stage.shows.count == 3)
    #expect(stage.shows.map(\.afterMenu) == [false, false, true])
    #expect(stage.hides == 0)
  }

  @Test func theSummonKeyHidesAShownPanelButTheMenuAndReopenKeepItShown() {
    let stage = Stage()
    let entry = stage.entry
    stage.shown = true
    entry.summon()
    #expect(stage.hides == 1)
    #expect(stage.shows.isEmpty)
    stage.shown = true
    entry.fromMenu(on: nil)
    entry.reopen()
    #expect(stage.hides == 1)
    #expect(stage.shown)
    #expect(stage.shows.count == 2)
  }

  @Test func theMenuShowsOnTheScreenWhoseMenuBarWasClicked() throws {
    let stage = Stage()
    let screen = try #require(NSScreen.screens.first)
    stage.entry.fromMenu(on: screen)
    #expect(stage.shows.first?.screen === screen)
  }

  @Test func keyLossRightAfterAMenuShowDoesNotHideThePanelButLaterKeyLossDoes() {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)
    var hold = KeyLossHold()
    #expect(!hold.holds(at: start))
    hold.start(at: start, duration: PanelController.menuCloseHold)
    #expect(hold.holds(at: start))
    #expect(hold.holds(at: start.addingTimeInterval(PanelController.menuCloseHold - 0.01)))
    #expect(!hold.holds(at: start.addingTimeInterval(PanelController.menuCloseHold)))
  }
}

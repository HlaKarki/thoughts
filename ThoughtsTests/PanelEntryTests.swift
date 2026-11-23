import AppKit
import Testing

@testable import Thoughts

@MainActor
struct PanelEntryTests {
  @MainActor
  final class Stage {
    var shown = false
    var shows: [NSScreen?] = []
    var hides = 0

    var entry: PanelEntry {
      PanelEntry(
        isShown: { self.shown },
        hide: {
          self.hides += 1
          self.shown = false
        },
        show: { screen in
          self.shows.append(screen)
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
    #expect(stage.shows.first.flatMap { $0 } === screen)
  }

  @Test func keyLossHidesThePanelUnlessKeepOpenIsOnOrItsOwnIconIsInUse() {
    #expect(PanelController.hidesOnKeyLoss(keepOpen: false, ownIconInUse: false))
    #expect(!PanelController.hidesOnKeyLoss(keepOpen: true, ownIconInUse: false))
    #expect(!PanelController.hidesOnKeyLoss(keepOpen: false, ownIconInUse: true))
    #expect(!PanelController.hidesOnKeyLoss(keepOpen: true, ownIconInUse: true))
  }
}

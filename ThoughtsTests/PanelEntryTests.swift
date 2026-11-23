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

  @Test func aShownPanelMovesToTheOtherDisplayAndRefocusesOnTheSameOne() {
    let first = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let second = CGRect(x: 1440, y: 0, width: 1920, height: 1055)
    let onFirst = PanelController.frame(in: first, edge: .right)
    func plan(isShown: Bool = true, visible: CGRect?) -> PanelShowPlan {
      PanelController.showPlan(
        isShown: isShown, panelFrame: onFirst, requestedVisible: visible, edge: .right)
    }
    #expect(plan(isShown: false, visible: second) == .fresh)
    #expect(plan(visible: nil) == .refocus)
    #expect(plan(visible: first) == .refocus)
    let moved = plan(visible: second)
    #expect(moved == .moveAndRefocus(PanelController.frame(in: second, edge: .right)))
    guard case .moveAndRefocus(let target) = moved else { return }
    #expect(second.contains(target))
    #expect(target.maxX == second.maxX - PanelController.edgeInset)
  }

  @Test func aClosedMenuRestoresKeyOnlyWithNoPickAndHidesAfterAnyOtherPick() {
    func outcome(_ pick: MenuPick, lost: Bool, keepOpen: Bool) -> MenuCloseOutcome {
      PanelController.afterMenuClosed(pick: pick, lostKeyToOwnIcon: lost, keepOpen: keepOpen)
    }
    #expect(outcome(.none, lost: true, keepOpen: false) == .restoreKey)
    #expect(outcome(.none, lost: true, keepOpen: true) == .restoreKey)
    #expect(outcome(.none, lost: false, keepOpen: false) == .none)
    #expect(outcome(.other, lost: true, keepOpen: false) == .hide)
    #expect(outcome(.other, lost: false, keepOpen: false) == .hide)
    #expect(outcome(.other, lost: true, keepOpen: true) == .none)
    #expect(outcome(.show, lost: true, keepOpen: false) == .none)
    #expect(outcome(.show, lost: true, keepOpen: true) == .none)
  }

  @Test func aLostKeyFlagSurvivesTheMenuOpeningOnlyForTheClickThatLostTheKey() {
    func held(event: Int?, opened: Int?, isShown: Bool = true, isKey: Bool = false) -> Bool {
      var tracker = LostKeyTracker()
      tracker.lostKey(toEvent: event)
      tracker.menuOpened(event: opened, isShown: isShown, isKey: isKey)
      return tracker.held
    }
    #expect(held(event: 5, opened: 5))
    #expect(!held(event: 5, opened: 5, isKey: true))
    #expect(!held(event: 5, opened: 5, isShown: false))
    #expect(!held(event: 5, opened: 9))
    #expect(!held(event: 5, opened: nil))
    #expect(!held(event: nil, opened: nil))
  }

  @Test func aClickThatOpenedNoMenuDoesNotRestoreTheKeyAtALaterMenuClosedWithNoPick() {
    var tracker = LostKeyTracker()
    tracker.lostKey(toEvent: 5)
    tracker.menuOpened(event: 9, isShown: true, isKey: false)
    let outcome = PanelController.afterMenuClosed(
      pick: .none, lostKeyToOwnIcon: tracker.held, keepOpen: false)
    #expect(outcome == .none)
  }

  @Test func aNewKeyLossReplacesTheClickRecordedByAnOlderOne() {
    var tracker = LostKeyTracker()
    tracker.lostKey(toEvent: 5)
    tracker.lostKey(toEvent: 9)
    tracker.menuOpened(event: 9, isShown: true, isKey: false)
    #expect(tracker.held)
  }
}

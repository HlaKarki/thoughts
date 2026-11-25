import AppKit
import Testing

@testable import Thoughts

@MainActor
@Suite(.serialized)
struct PanelHarnessTests {
  @Test func upInTheEmptyInputSelectsTheNewestThoughtThroughTheKeyMonitor() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["older", "newest"])
      try await harness.show()
      let newest = try #require(harness.list.visible.last?.fileName)
      await harness.press(.up)
      #expect(harness.list.selection == [newest])
      #expect(harness.list.focus == .list)
    }
  }

  @Test func theSameUpSentStraightToTheWindowSkipsTheMonitorAndSelectsNothing() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["older", "newest"])
      try await harness.show()
      let event = try #require(harness.keyEvent(.up))
      harness.panel.sendEvent(event)
      await harness.settle()
      #expect(harness.list.selection.isEmpty)
      #expect(harness.list.focus == .input)
    }
  }

  @Test func typedLettersReachTheFieldEditorOfTheInput() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      await harness.type("hello")
      #expect(harness.input.text == "hello")
      #expect(harness.firstResponderText == "hello")
      #expect(harness.panel.firstResponder === harness.inputField?.currentEditor())
    }
  }

  @Test func commandZWithNothingToUndoReachesThePanelKeyEquivalent() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      await harness.press(.character("z"), .command)
      #expect(harness.historySteps == [.undo])
      #expect(harness.list.feedback?.text == "Nothing to undo")
    }
  }

  @Test func thePanelStaysOffEveryScreenAndNeverBecomesKey() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one"])
      try await harness.show()
      await harness.type("abc")
      await harness.press(.up)
      #expect(harness.panel.isVisible)
      #expect(harness.panel.windowNumber > 0)
      #expect(!NSScreen.screens.contains { $0.frame.intersects(harness.panel.frame) })
      #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
      #expect(!harness.panel.isKeyWindow)
      #expect(KeyWindowSeam.appKitKeyWindow == nil)
      #expect(NSApp.isActive == harness.startedActive)
      #expect(harness.isolationChecks == 3)
      #expect(harness.seenKeyDowns == 4)
      #expect(harness.foreignKeys == 0)
    }
  }

  @Test func postedArrowsCarryTheFlagsOfARealArrowPress() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      let device: NSEvent.ModifierFlags = [.function, .numericPad]
      for key in [PanelHarness.Key.up, .down] {
        let event = try #require(harness.keyEvent(key, .shift))
        #expect(event.modifierFlags.isSuperset(of: device.union(.shift)))
      }
      let escape = try #require(harness.keyEvent(.escape))
      #expect(escape.modifierFlags.isDisjoint(with: device))
    }
  }

  @Test func aCharacterWithNoKeyCodeFailsInsteadOfTypingA() async throws {
    try await PanelHarness.run { harness in
      try await harness.show()
      await withKnownIssue("the harness records an issue for a character it cannot type") {
        await harness.type("1")
      }
      #expect(harness.seenKeyDowns == 0)
      #expect(harness.input.text == "")
    }
  }

  @Test func thePanelRendersToAPNG() async throws {
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two"])
      try await harness.show()
      await harness.type("draft")
      let url = try harness.snapshot("PanelHarness-draft")
      let image = try #require(NSBitmapImageRep(data: try Data(contentsOf: url)))
      #expect(image.pixelsWide == Int(PanelController.width) * SnapshotRenderer.scale)
      #expect(image.pixelsHigh == Int(PanelController.maxHeight) * SnapshotRenderer.scale)
    }
  }

  @Test func theScreenCheckCountsOnlyWindowsWithAnAreaThatTouchesAScreen() {
    let screens = [CGRect(x: 0, y: 0, width: 1728, height: 1117)]
    let chip = CGRect(x: 100, y: 100, width: 300, height: 60)
    #expect(PanelHarness.showsOnScreen(chip, screens: screens))
    #expect(PanelHarness.showsOnScreen(chip.offsetBy(dx: -350, dy: 0), screens: screens))
    #expect(!PanelHarness.showsOnScreen(.zero, screens: screens))
    #expect(
      !PanelHarness.showsOnScreen(CGRect(x: 10, y: 10, width: 0, height: 40), screens: screens))
    #expect(!PanelHarness.showsOnScreen(chip.offsetBy(dx: 6000, dy: 0), screens: screens))
  }
}

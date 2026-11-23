import Foundation
import Testing

@testable import Thoughts

@MainActor
struct MenuBarCopyTests {
  @Test func everyPlaceThatNamesTheIconOnlyDoesSoWhileItIsShown() {
    for shown in [true, false] {
      let texts = [
        MenuBarCopy.summonKeyMessage(iconShown: shown),
        MenuBarCopy.settingsExplanation(iconShown: shown),
      ]
      for text in texts {
        #expect(text.localizedCaseInsensitiveContains("icon") == shown)
      }
    }
  }

  @Test func theCopyAlwaysSaysHowToReachThePanelWithTheSummonKeyOrAnotherWay() {
    #expect(MenuBarCopy.summonKeyMessage(iconShown: false).contains("show or hide the panel"))
    #expect(MenuBarCopy.summonKeyMessage(iconShown: true).contains("show or hide the panel"))
    #expect(MenuBarCopy.settingsExplanation(iconShown: true).contains("summon key"))
    let hidden = MenuBarCopy.settingsExplanation(iconShown: false)
    #expect(hidden.contains("summon key"))
    #expect(hidden.contains("open Thoughts again"))
  }

  @Test func theFirstRunStepAndTheSettingsRowReadTheSameSetting() throws {
    let preferences = try SettingsFixtures.preferences()
    #expect(preferences.showsMenuBarIcon)
    let model = try SettingsFixtures.firstRun(system: FakeSystem(), preferences: preferences)
    #expect(model.preferences.showsMenuBarIcon)
    preferences.showsMenuBarIcon = false
    #expect(!model.preferences.showsMenuBarIcon)
  }
}

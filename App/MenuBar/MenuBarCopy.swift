import Foundation

enum MenuBarCopy {
  static func summonKeyMessage(iconShown: Bool) -> String {
    iconShown
      ? String(
        localized:
          "Press it in any app to show or hide the panel, or choose Show Thoughts from the Thoughts icon in the menu bar."
      ) : String(localized: "Press it in any app to show or hide the panel.")
  }

  static func settingsExplanation(iconShown: Bool) -> String {
    iconShown
      ? String(
        localized:
          "Choose Show Thoughts from the Thoughts icon in the menu bar. The summon key works too.")
      : String(
        localized:
          "Press the summon key, or open Thoughts again from Applications, to show the panel.")
  }
}

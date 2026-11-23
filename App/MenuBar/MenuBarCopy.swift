import Foundation

enum MenuBarCopy {
  static func summonKeyMessage(iconShown: Bool) -> String {
    iconShown
      ? String(
        localized:
          "Press it in any app to show or hide the panel. You can also click the Thoughts icon in the menu bar."
      ) : String(localized: "Press it in any app to show or hide the panel.")
  }

  static func settingsExplanation(iconShown: Bool) -> String {
    iconShown
      ? String(localized: "Click the icon to show the panel. The summon key works too.")
      : String(
        localized:
          "Press the summon key, or open Thoughts again from Applications, to show the panel.")
  }
}

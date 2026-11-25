import AppKit

@MainActor
struct PanelEntry {
  var isShown: () -> Bool
  var isKey: () -> Bool
  var wasKeyWhenMenuOpened: () -> Bool
  var keepsOpen: () -> Bool
  var hide: () -> Void
  var show: (_ screen: NSScreen?) -> Void

  init(
    isShown: @escaping () -> Bool, isKey: @escaping () -> Bool,
    wasKeyWhenMenuOpened: @escaping () -> Bool, keepsOpen: @escaping () -> Bool,
    hide: @escaping () -> Void, show: @escaping (_ screen: NSScreen?) -> Void
  ) {
    self.isShown = isShown
    self.isKey = isKey
    self.wasKeyWhenMenuOpened = wasKeyWhenMenuOpened
    self.keepsOpen = keepsOpen
    self.hide = hide
    self.show = show
  }

  init(_ panel: PanelController) {
    self.init(
      isShown: { panel.isShown }, isKey: { panel.isKey },
      wasKeyWhenMenuOpened: { panel.wasKeyWhenOwnMenuOpened },
      keepsOpen: { panel.keepsOpen }, hide: { panel.hide() },
      show: { panel.show(on: $0) })
  }

  func summon() {
    if isShown(), isKey() || !keepsOpen() { hide() } else { show(nil) }
  }

  func reopen() {
    show(nil)
  }

  func fromMenu(on screen: NSScreen?) {
    if isShown(), keepsOpen(), wasKeyWhenMenuOpened() { hide() } else { show(screen) }
  }
}

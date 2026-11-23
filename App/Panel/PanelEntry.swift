import AppKit

@MainActor
struct PanelEntry {
  var isShown: () -> Bool
  var hide: () -> Void
  var show: (_ screen: NSScreen?) -> Void

  init(
    isShown: @escaping () -> Bool, hide: @escaping () -> Void,
    show: @escaping (_ screen: NSScreen?) -> Void
  ) {
    self.isShown = isShown
    self.hide = hide
    self.show = show
  }

  init(_ panel: PanelController) {
    self.init(
      isShown: { panel.isShown }, hide: { panel.hide() },
      show: { panel.show(on: $0) })
  }

  func summon() {
    if isShown() { hide() } else { show(nil) }
  }

  func reopen() {
    show(nil)
  }

  func fromMenu(on screen: NSScreen?) {
    show(screen)
  }
}

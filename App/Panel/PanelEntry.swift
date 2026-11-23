import AppKit

struct KeyLossHold {
  private var until: Date?

  mutating func start(at date: Date, duration: TimeInterval) {
    until = date.addingTimeInterval(duration)
  }

  func holds(at date: Date) -> Bool {
    guard let until else { return false }
    return date < until
  }
}

@MainActor
struct PanelEntry {
  var isShown: () -> Bool
  var hide: () -> Void
  var show: (_ screen: NSScreen?, _ afterMenu: Bool) -> Void

  init(
    isShown: @escaping () -> Bool, hide: @escaping () -> Void,
    show: @escaping (_ screen: NSScreen?, _ afterMenu: Bool) -> Void
  ) {
    self.isShown = isShown
    self.hide = hide
    self.show = show
  }

  init(_ panel: PanelController) {
    self.init(
      isShown: { panel.isShown }, hide: { panel.hide() },
      show: { panel.show(on: $0, afterMenu: $1) })
  }

  func summon() {
    if isShown() { hide() } else { show(nil, false) }
  }

  func reopen() {
    show(nil, false)
  }

  func fromMenu(on screen: NSScreen?) {
    show(screen, true)
  }
}

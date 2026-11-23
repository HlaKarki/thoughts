import AppKit
import Observation

@MainActor
final class MenuBarController {
  private let preferences: Preferences
  private let updates: UpdateMenuItem
  private let surface: StatusItemSurface
  private let menu: MenuBarMenu
  private var running = false

  init(
    preferences: Preferences, updates: UpdateMenuItem, surface: StatusItemSurface,
    menu: MenuBarMenu, showPanel: @escaping @MainActor (_ screen: NSScreen?) -> Void
  ) {
    self.preferences = preferences
    self.updates = updates
    self.surface = surface
    self.menu = menu
    menu.onShow = { [surface] in showPanel(surface.screen) }
  }

  func start() {
    guard !running else { return }
    running = true
    surface.onRemoved = { [weak self] in self?.preferences.showsMenuBarIcon = false }
    apply()
    follow()
  }

  func stop() {
    running = false
    surface.onRemoved = nil
  }

  func ownIconInUse(event: NSEvent?) -> Bool {
    menu.isOpen || surface.isOwnClick(event)
  }

  func apply() {
    if surface.isVisible != preferences.showsMenuBarIcon {
      surface.isVisible = preferences.showsMenuBarIcon
    }
    let waiting = updates.isShown
    surface.present(updateWaiting: waiting, label: MenuBarGlyph.label(updateWaiting: waiting))
  }

  private func follow() {
    withObservationTracking {
      _ = preferences.showsMenuBarIcon
      _ = updates.isShown
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self, self.running else { return }
        self.apply()
        self.follow()
      }
    }
  }
}

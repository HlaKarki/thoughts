import AppKit
import Observation

@MainActor
final class MenuBarController {
  private let preferences: Preferences
  private let updates: UpdateMenuItem
  private let surface: StatusItemSurface
  private let menu: MenuBarMenu
  private let differentiate: @MainActor () -> Bool
  private let accessibilityCenter: NotificationCenter
  private var accessibilityObserver: NSObjectProtocol?
  private var running = false

  init(
    preferences: Preferences, updates: UpdateMenuItem, surface: StatusItemSurface,
    menu: MenuBarMenu, showPanel: @escaping @MainActor (_ screen: NSScreen?) -> Void,
    differentiate: @escaping @MainActor () -> Bool = {
      NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor
    },
    accessibilityCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
  ) {
    self.differentiate = differentiate
    self.accessibilityCenter = accessibilityCenter
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
    accessibilityObserver = accessibilityCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.apply() }
    }
    apply()
    follow()
  }

  func stop() {
    running = false
    surface.onRemoved = nil
    if let accessibilityObserver { accessibilityCenter.removeObserver(accessibilityObserver) }
    accessibilityObserver = nil
  }

  func ownIconInUse(event: NSEvent?) -> Bool {
    menu.isOpen || surface.isOwnClick(event)
  }

  func apply() {
    if surface.isVisible != preferences.showsMenuBarIcon {
      surface.isVisible = preferences.showsMenuBarIcon
    }
    let waiting = updates.isShown
    surface.present(
      updateWaiting: waiting, differentiate: differentiate(),
      label: MenuBarGlyph.label(updateWaiting: waiting))
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

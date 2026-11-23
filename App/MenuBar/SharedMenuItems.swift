import AppKit

struct SharedMenuItem {
  enum ID: String, CaseIterable {
    case updateAvailable
    case settings
    case checkForUpdates
    case quit
  }

  let id: ID
  let title: String
  let isEnabled: Bool
  let perform: @MainActor () -> Void
}

@MainActor
final class SharedMenuItems {
  let updates: UpdateMenuItem
  private let onOpenSettings: (@MainActor () -> Void)?
  private let onCheckForUpdates: (@MainActor () -> Void)?
  private let onQuit: @MainActor () -> Void

  init(
    updates: UpdateMenuItem,
    openSettings: (@MainActor () -> Void)?,
    checkForUpdates: (@MainActor () -> Void)?,
    quit: @escaping @MainActor () -> Void = { NSApp.terminate(nil) }
  ) {
    self.updates = updates
    onOpenSettings = openSettings
    onCheckForUpdates = checkForUpdates
    onQuit = quit
  }

  var isUpdateWaiting: Bool { updates.isShown }

  var updateAvailable: SharedMenuItem? {
    isUpdateWaiting ? item(.updateAvailable) : nil
  }

  var settings: SharedMenuItem { item(.settings) }
  var checkForUpdates: SharedMenuItem { item(.checkForUpdates) }
  var quit: SharedMenuItem { item(.quit) }

  func item(_ id: SharedMenuItem.ID) -> SharedMenuItem {
    switch id {
    case .updateAvailable:
      SharedMenuItem(
        id: id, title: String(localized: "Update available"),
        isEnabled: onCheckForUpdates != nil, perform: { [onCheckForUpdates] in onCheckForUpdates?() }
      )
    case .settings:
      SharedMenuItem(
        id: id, title: String(localized: "Settings…"), isEnabled: onOpenSettings != nil,
        perform: { [onOpenSettings] in onOpenSettings?() })
    case .checkForUpdates:
      SharedMenuItem(
        id: id, title: String(localized: "Check for updates…"),
        isEnabled: onCheckForUpdates != nil,
        perform: { [onCheckForUpdates] in onCheckForUpdates?() })
    case .quit:
      SharedMenuItem(
        id: id, title: String(localized: "Quit Thoughts"), isEnabled: true,
        perform: { [onQuit] in onQuit() })
    }
  }
}

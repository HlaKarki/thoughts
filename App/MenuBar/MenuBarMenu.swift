import AppKit
import KeyboardShortcuts

@MainActor
final class MenuBarMenu: NSObject, NSMenuDelegate {
  static let showID = NSUserInterfaceItemIdentifier("show")

  let menu = NSMenu()
  var onShow: @MainActor () -> Void = {}
  private let shared: SharedMenuItems
  private let summon: KeyboardShortcuts.Name
  private let setSummonEnabled: @MainActor (KeyboardShortcuts.Name, Bool) -> Void
  private let showItem = NSMenuItem()
  private var sharedItems: [SharedMenuItem.ID: NSMenuItem] = [:]

  init(
    shared: SharedMenuItems,
    summon: KeyboardShortcuts.Name = .summon,
    setSummonEnabled: @escaping @MainActor (KeyboardShortcuts.Name, Bool) -> Void = {
      name, enabled in
      if enabled {
        KeyboardShortcuts.enable(name)
      } else {
        KeyboardShortcuts.disable(name)
      }
    }
  ) {
    self.shared = shared
    self.summon = summon
    self.setSummonEnabled = setSummonEnabled
    super.init()
    menu.autoenablesItems = false
    menu.delegate = self
    showItem.title = String(localized: "Show Thoughts")
    showItem.identifier = Self.showID
    showItem.target = self
    showItem.action = #selector(choose(_:))
    showItem.setShortcut(for: summon)
    refresh()
  }

  func refresh() {
    menu.removeAllItems()
    menu.addItem(showItem)
    menu.addItem(.separator())
    if let update = shared.updateAvailable { menu.addItem(item(for: update)) }
    menu.addItem(item(for: shared.settings))
    menu.addItem(item(for: shared.checkForUpdates))
    menu.addItem(.separator())
    menu.addItem(item(for: shared.quit))
  }

  private func item(for shared: SharedMenuItem) -> NSMenuItem {
    let item =
      sharedItems[shared.id]
      ?? {
        let created = NSMenuItem()
        created.identifier = NSUserInterfaceItemIdentifier(shared.id.rawValue)
        created.target = self
        created.action = #selector(choose(_:))
        sharedItems[shared.id] = created
        return created
      }()
    item.title = shared.title
    item.isEnabled = shared.isEnabled
    return item
  }

  @objc private func choose(_ sender: NSMenuItem) {
    guard let identifier = sender.identifier else { return }
    if identifier == Self.showID {
      onShow()
    } else if let id = SharedMenuItem.ID(rawValue: identifier.rawValue) {
      shared.item(id).perform()
    }
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    refresh()
  }

  func menuWillOpen(_ menu: NSMenu) {
    setSummonEnabled(summon, false)
  }

  func menuDidClose(_ menu: NSMenu) {
    setSummonEnabled(summon, true)
  }
}

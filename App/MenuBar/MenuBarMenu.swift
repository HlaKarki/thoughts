import AppKit
import KeyboardShortcuts

enum MenuPick: Equatable {
  case none
  case show
  case other
}

struct MenuShowGate {
  private(set) var isOpen = false
  private var pending = false

  mutating func opened() {
    isOpen = true
  }

  mutating func closed() -> Bool {
    isOpen = false
    defer { pending = false }
    return pending
  }

  mutating func chose() -> Bool {
    if isOpen {
      pending = true
      return false
    }
    return true
  }
}

@MainActor
final class MenuBarMenu: NSObject, NSMenuDelegate {
  static let showID = NSUserInterfaceItemIdentifier("show")

  let menu = NSMenu()
  var onShow: @MainActor () -> Void = {}
  var onClosed: @MainActor (MenuPick) -> Void = { _ in }
  var onOpened: @MainActor () -> Void = {}
  private var pick = MenuPick.none
  var isOpen: Bool { gate.isOpen }
  private var gate = MenuShowGate()
  private let afterTracking: @MainActor (@escaping @MainActor () -> Void) -> Void
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
    },
    afterTracking: @escaping @MainActor (@escaping @MainActor () -> Void) -> Void = { work in
      RunLoop.main.perform(inModes: [.default]) { MainActor.assumeIsolated { work() } }
    }
  ) {
    self.shared = shared
    self.afterTracking = afterTracking
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
      pick = .show
      if gate.chose() { showAfterTracking() }
    } else if let id = SharedMenuItem.ID(rawValue: identifier.rawValue) {
      pick = .other
      shared.item(id).perform()
    }
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    refresh()
  }

  func menuWillOpen(_ menu: NSMenu) {
    gate.opened()
    pick = .none
    setSummonEnabled(summon, false)
    onOpened()
  }

  func menuDidClose(_ menu: NSMenu) {
    setSummonEnabled(summon, true)
    afterTracking { [weak self] in
      guard let self else { return }
      let chosen = pick
      pick = .none
      onClosed(chosen)
    }
    if gate.closed() { showAfterTracking() }
  }

  private func showAfterTracking() {
    afterTracking { [weak self] in self?.onShow() }
  }
}

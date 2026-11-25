import AppKit

@MainActor
final class AppMenu: NSObject, NSMenuItemValidation {
  let menu = NSMenu()
  private let windows = NSMenu(title: String(localized: "Window"))
  private let shared: SharedMenuItems
  private let appName: String

  init(
    shared: SharedMenuItems,
    appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? "Thoughts"
  ) {
    self.shared = shared
    self.appName = appName
    super.init()
    menu.addItem(container(for: appMenu()))
    menu.addItem(container(for: editMenu()))
    menu.addItem(container(for: windowMenu()))
  }

  func install() {
    NSApp.mainMenu = menu
    NSApp.windowsMenu = windows
  }

  func validateMenuItem(_ item: NSMenuItem) -> Bool {
    switch item.action {
    case #selector(openSettings(_:)): shared.settings.isEnabled
    case #selector(quit(_:)): shared.quit.isEnabled
    default: true
    }
  }

  @objc private func openSettings(_ sender: Any?) {
    shared.settings.perform()
  }

  @objc private func quit(_ sender: Any?) {
    shared.quit.perform()
  }

  private func container(for submenu: NSMenu) -> NSMenuItem {
    let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
    item.submenu = submenu
    return item
  }

  private func item(
    _ title: String, _ action: Selector?, _ key: String,
    modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = modifiers
    item.target = target
    return item
  }

  private func appMenu() -> NSMenu {
    let menu = NSMenu(title: appName)
    menu.addItem(item(shared.settings.title, #selector(openSettings(_:)), ",", target: self))
    menu.addItem(.separator())
    menu.addItem(
      item(
        String(localized: "Hide \(appName)"), #selector(NSApplication.hide(_:)), "h",
        target: NSApp))
    menu.addItem(
      item(
        String(localized: "Hide Others"), #selector(NSApplication.hideOtherApplications(_:)), "h",
        modifiers: [.command, .option], target: NSApp))
    menu.addItem(
      item(
        String(localized: "Show All"), #selector(NSApplication.unhideAllApplications(_:)), "",
        target: NSApp))
    menu.addItem(.separator())
    menu.addItem(item(shared.quit.title, #selector(quit(_:)), "q", target: self))
    return menu
  }

  private func editMenu() -> NSMenu {
    let menu = NSMenu(title: String(localized: "Edit"))
    menu.addItem(item(String(localized: "Undo"), Selector(("undo:")), "z"))
    menu.addItem(
      item(String(localized: "Redo"), Selector(("redo:")), "Z", modifiers: [.command, .shift]))
    menu.addItem(.separator())
    menu.addItem(item(String(localized: "Cut"), #selector(NSText.cut(_:)), "x"))
    menu.addItem(item(String(localized: "Copy"), #selector(NSText.copy(_:)), "c"))
    menu.addItem(item(String(localized: "Paste"), #selector(NSText.paste(_:)), "v"))
    menu.addItem(item(String(localized: "Select All"), #selector(NSText.selectAll(_:)), "a"))
    return menu
  }

  private func windowMenu() -> NSMenu {
    windows.addItem(
      item(String(localized: "Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"))
    windows.addItem(item(String(localized: "Close"), #selector(NSWindow.performClose(_:)), "w"))
    return windows
  }
}

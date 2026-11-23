import AppKit

enum MainMenu {
  static func build() -> NSMenu {
    let menu = NSMenu()
    let app = NSMenuItem()
    app.submenu = NSMenu()
    menu.addItem(app)
    let edit = NSMenuItem()
    edit.submenu = editMenu()
    menu.addItem(edit)
    return menu
  }

  private static func editMenu() -> NSMenu {
    let menu = NSMenu(title: String(localized: "Edit"))
    menu.addItem(item("Undo", Selector(("undo:")), "z"))
    menu.addItem(item("Redo", Selector(("redo:")), "z", [.command, .shift]))
    menu.addItem(.separator())
    menu.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
    menu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
    menu.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
    menu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
    return menu
  }

  private static func item(
    _ title: String.LocalizationValue, _ action: Selector, _ key: String,
    _ modifiers: NSEvent.ModifierFlags = .command
  ) -> NSMenuItem {
    let item = NSMenuItem(title: String(localized: title), action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = modifiers
    return item
  }
}

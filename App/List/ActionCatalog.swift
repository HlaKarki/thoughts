import Foundation
import ThoughtsCore

struct ActionItem: Identifiable, Equatable {
  let id: String
  let title: String
  let shortcut: String
  let command: KeyCommand
  let destructive: Bool
}

enum ActionCatalog {
  static func items(for selection: [ThoughtEntry]) -> [ActionItem] {
    guard !selection.isEmpty else { return [] }
    let thoughts = selection.compactMap(\.thought)
    let single = selection.count == 1
    let readable = thoughts.count == selection.count
    var items: [ActionItem] = []
    if readable { items.append(copy()) }
    items.append(item("copyPath", String(localized: "Copy path"), "⇧⌘C", .copyPath))
    guard readable else {
      items.append(showInFinder)
      return items
    }
    if single { items.append(item("edit", String(localized: "Edit"), "↵", .edit)) }
    let allDone = thoughts.allSatisfy { $0.done != nil }
    items.append(
      item(
        "toggleDone",
        allDone ? String(localized: "Mark not done") : String(localized: "Mark done"), "⌘↵",
        .toggleDone))
    if single { items.append(item("preview", String(localized: "Preview"), "Space", .preview)) }
    if single, SourceOpener.canOpen(thoughts[0].source) {
      items.append(item("openSource", String(localized: "Open original"), "⌘O", .openSource))
    }
    items.append(showInFinder)
    items.append(item("delete", String(localized: "Delete"), "⌘⌫", .delete, destructive: true))
    return items
  }

  static func filter(_ items: [ActionItem], by query: String) -> [ActionItem] {
    guard !query.isEmpty else { return items }
    return items.filter { $0.title.range(of: query, options: .caseInsensitive) != nil }
  }

  private static var showInFinder: ActionItem {
    item("showInFinder", String(localized: "Show in Finder"), "⌘R", .showInFinder)
  }

  private static func copy() -> ActionItem {
    item("copy", String(localized: "Copy"), "⌘C", .copy)
  }

  private static func item(
    _ id: String, _ title: String, _ shortcut: String, _ command: KeyCommand,
    destructive: Bool = false
  ) -> ActionItem {
    ActionItem(
      id: id, title: title, shortcut: shortcut, command: command, destructive: destructive)
  }
}

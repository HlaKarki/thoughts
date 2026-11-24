import SwiftUI

enum KeyRouter {
  static func command(
    for press: KeyStroke, focus: Focus, menuIsOpen: Bool, inputIsEmpty: Bool,
    hasAttachment: Bool
  ) -> KeyCommand? {
    let focus = menuIsOpen ? .menu : focus
    let modifiers = press.modifiers
    if press.key == .escape, modifiers.isEmpty {
      return escape(focus: focus, hasAttachment: hasAttachment)
    }
    if press.key == KeyEquivalent("f"), modifiers == .command, focus != .menu, focus != .edit {
      return .focusSearch
    }
    switch focus {
    case .input: return input(press, inputIsEmpty: inputIsEmpty)
    case .search: return search(press)
    case .list: return list(press)
    case .menu: return menu(press)
    case .edit: return editing(press)
    }
  }

  private static func escape(focus: Focus, hasAttachment: Bool) -> KeyCommand {
    switch focus {
    case .input: hasAttachment ? .removeAttachment : .hidePanel
    case .search: .clearSearch
    case .list: .backToInput
    case .menu: .menuClose
    case .edit: .cancelEdit
    }
  }

  private static func input(_ press: KeyStroke, inputIsEmpty: Bool) -> KeyCommand? {
    switch (press.key, press.modifiers) {
    case (.return, []): .add
    case (.upArrow, []) where inputIsEmpty: .selectNewest
    default: nil
    }
  }

  private static func search(_ press: KeyStroke) -> KeyCommand? {
    switch (press.key, press.modifiers) {
    case (.downArrow, []): .move(1)
    default: nil
    }
  }

  private static func editing(_ press: KeyStroke) -> KeyCommand? {
    switch (press.key, press.modifiers) {
    case (.return, []): .saveEdit
    default: nil
    }
  }

  private static func menu(_ press: KeyStroke) -> KeyCommand? {
    switch (press.key, press.modifiers) {
    case (.upArrow, []): .menuMove(-1)
    case (.downArrow, []): .menuMove(1)
    case (.return, []): .menuRun
    case (KeyEquivalent("k"), .command): .menuClose
    default: nil
    }
  }

  private static func list(_ press: KeyStroke) -> KeyCommand? {
    switch (press.key, press.modifiers) {
    case (.upArrow, []): .move(-1)
    case (.downArrow, []): .move(1)
    case (.upArrow, .shift): .extend(-1)
    case (.downArrow, .shift): .extend(1)
    case (.return, []): .edit
    case (.return, .command): .toggleDone
    case (.space, []): .preview
    case (.delete, .command): .delete
    case (KeyEquivalent("c"), .command): .copy
    case (KeyEquivalent("c"), [.command, .shift]): .copyPath
    case (KeyEquivalent("o"), .command): .openSource
    case (KeyEquivalent("r"), .command): .showInFinder
    case (KeyEquivalent("k"), .command): .actionsMenu
    default: typed(press).map(KeyCommand.type)
    }
  }

  private static func typed(_ press: KeyStroke) -> String? {
    guard press.modifiers.isDisjoint(with: [.command, .control]) else { return nil }
    let scalars = press.characters.unicodeScalars
    guard !scalars.isEmpty, scalars.allSatisfy(isPrintable) else { return nil }
    return press.characters
  }

  private static func isPrintable(_ scalar: Unicode.Scalar) -> Bool {
    let functionKeys: ClosedRange<UInt32> = 0xF700...0xF8FF
    return !CharacterSet.controlCharacters.contains(scalar)
      && !CharacterSet.whitespacesAndNewlines.contains(scalar)
      && !functionKeys.contains(scalar.value)
  }
}

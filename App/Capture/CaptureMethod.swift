import KeyboardShortcuts
import SwiftUI
import ThoughtsCore

enum CaptureMethod: Hashable {
  case doubleTap(Modifier)
  case shortcut
  case off

  static let all: [CaptureMethod] = [
    .doubleTap(.shift), .doubleTap(.option), .doubleTap(.control), .doubleTap(.command),
    .shortcut, .off,
  ]

  var modifier: Modifier? {
    if case .doubleTap(let modifier) = self { modifier } else { nil }
  }

  var title: LocalizedStringKey {
    switch self {
    case .doubleTap(let modifier): modifier.twiceTitle
    case .shortcut: "Use a shortcut"
    case .off: "Off"
    }
  }

  func keycap(shortcut: String?) -> KeycapContent? {
    switch self {
    case .doubleTap(let modifier): .doubled(modifier)
    case .shortcut: shortcut.flatMap { $0.isEmpty ? nil : KeycapContent.text($0) }
    case .off: nil
    }
  }

  @MainActor
  static var captureShortcutText: String? {
    KeyboardShortcuts.getShortcut(for: .capture)?.description
  }

  @MainActor
  var keycap: KeycapContent? { keycap(shortcut: Self.captureShortcutText) }
}

enum KeycapContent: Equatable {
  case doubled(Modifier)
  case text(String)

  var plain: String {
    switch self {
    case .doubled(let modifier): String(repeating: modifier.glyph, count: 2)
    case .text(let text): text
    }
  }

  var inline: Text {
    switch self {
    case .doubled(let modifier):
      Text("\(Image(systemName: modifier.symbolName))\(Image(systemName: modifier.symbolName))")
    case .text(let text): Text(verbatim: text)
    }
  }
}

extension Modifier {
  var glyph: String {
    switch self {
    case .shift: "⇧"
    case .option: "⌥"
    case .control: "⌃"
    case .command: "⌘"
    }
  }
}

extension Notification.Name {
  static let captureShortcutChanged = Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")
}

struct MethodPicker: View {
  @Binding var selection: CaptureMethod

  var body: some View {
    Picker("", selection: $selection) {
      ForEach(CaptureMethod.all, id: \.self) { method in
        Text(method.title).tag(method)
      }
    }
    .labelsHidden()
    .pickerStyle(.menu)
  }
}

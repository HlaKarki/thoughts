import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let summon = Self("summon", initial: .init(.n, modifiers: [.control, .option]))
  static let capture = Self("capture")
}

enum SummonShortcut {
  @MainActor
  static func listen(_ onPress: @escaping @MainActor () -> Void) -> Task<Void, Never> {
    Task { @MainActor in
      for await event in KeyboardShortcuts.events(for: .summon) where event == .keyDown {
        onPress()
      }
    }
  }
}

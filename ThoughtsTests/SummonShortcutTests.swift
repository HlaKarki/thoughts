import KeyboardShortcuts
import Testing

@testable import Thoughts

struct SummonShortcutTests {
  @Test func theSummonKeyStartsAsOptionN() {
    #expect(
      KeyboardShortcuts.Name.summon.initialShortcut == .init(.n, modifiers: [.option]))
  }
}

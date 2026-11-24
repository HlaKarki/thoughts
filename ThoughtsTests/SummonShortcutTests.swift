import KeyboardShortcuts
import Testing

@testable import Thoughts

struct SummonShortcutTests {
  @Test func theSummonKeyStartsAsControlOptionN() {
    #expect(
      KeyboardShortcuts.Name.summon.initialShortcut == .init(.n, modifiers: [.control, .option]))
  }
}

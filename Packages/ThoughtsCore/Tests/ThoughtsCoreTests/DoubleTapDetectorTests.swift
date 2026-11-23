import Testing

@testable import ThoughtsCore

struct DoubleTapDetectorTests {
  static func press(_ time: Double, _ modifiers: Set<Modifier> = [.shift]) -> ModifierEvent {
    .modifiers(modifiers, at: time)
  }

  static func release(_ time: Double) -> ModifierEvent {
    .modifiers([], at: time)
  }

  static func run(_ events: [ModifierEvent]) -> [Bool] {
    var detector = DoubleTapDetector(modifier: .shift)
    return events.map { detector.feed($0) }
  }

  @Test func twoQuickTapsFire() {
    let fired = Self.run([Self.press(0), Self.release(0.10), Self.press(0.30), Self.release(0.38)])
    #expect(fired == [false, false, false, true])
  }

  @Test func slowSecondTapDoesNotFire() {
    let fired = Self.run([Self.press(0), Self.release(0.10), Self.press(0.60), Self.release(0.68)])
    #expect(!fired.contains(true))
  }

  @Test func longHoldDoesNotFire() {
    let fired = Self.run([Self.press(0), Self.release(0.10), Self.press(0.30), Self.release(0.70)])
    #expect(!fired.contains(true))
  }

  @Test func keyBetweenTapsCancels() {
    let fired = Self.run([
      Self.press(0), Self.release(0.10), .key(at: 0.15), Self.press(0.30), Self.release(0.38),
    ])
    #expect(!fired.contains(true))
  }

  @Test func otherModifierCancels() {
    let fired = Self.run([
      Self.press(0), Self.release(0.10), Self.press(0.30, [.shift, .command]),
      Self.release(0.38),
    ])
    #expect(!fired.contains(true))
  }

  @Test func thirdTapStartsOver() {
    let fired = Self.run([
      Self.press(0), Self.release(0.10), Self.press(0.30), Self.release(0.38),
      Self.press(0.50), Self.release(0.58),
    ])
    #expect(fired.filter { $0 }.count == 1)
    #expect(fired.last == false)
  }

  @Test func keyDuringAHoldIsNotATap() {
    let fired = Self.run([
      Self.press(0), .key(at: 0.05), Self.release(0.10), Self.press(0.30), Self.release(0.38),
    ])
    #expect(!fired.contains(true))
  }

  @Test func otherModifierTapsAreIgnored() {
    var detector = DoubleTapDetector(modifier: .option)
    let events: [ModifierEvent] = [
      .modifiers([.shift], at: 0), .modifiers([], at: 0.1),
      .modifiers([.shift], at: 0.3), .modifiers([], at: 0.38),
    ]
    #expect(!events.map { detector.feed($0) }.contains(true))
  }
}

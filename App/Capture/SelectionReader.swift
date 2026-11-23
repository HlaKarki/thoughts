import AppKit
import Carbon.HIToolbox
import ThoughtsCore

@MainActor
protocol SelectionReading: AnyObject {
  func probe(pid: Int32) async -> SelectionProbe
  func copySelection() async -> (SelectionProbe, ownChangeCounts: [Int])
}

enum CopyKeyPoster {
  @MainActor
  static func post() {
    guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
    let source = CGEventSource(stateID: .privateState)
    for keyDown in [true, false] {
      guard
        let event = CGEvent(
          keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: keyDown)
      else { continue }
      event.flags = .maskCommand
      event.postToPid(pid)
    }
  }
}

@MainActor
final class SelectionReader: SelectionReading {
  static let copyWait: Duration = .milliseconds(300)
  static let settle: Duration = .milliseconds(30)

  private let pasteboard: NSPasteboard
  private let readSelection: @Sendable (Int32) -> SelectionProbe
  private let postCopy: @MainActor () -> Void

  init(
    pasteboard: NSPasteboard = .general,
    readSelection: @escaping @Sendable (Int32) -> SelectionProbe = { _ in .unavailable },
    postCopy: @escaping @MainActor () -> Void = CopyKeyPoster.post
  ) {
    self.pasteboard = pasteboard
    self.readSelection = readSelection
    self.postCopy = postCopy
  }

  func probe(pid: Int32) async -> SelectionProbe {
    let readSelection = readSelection
    return await Task.detached { readSelection(pid) }.value
  }

  func copySelection() async -> (SelectionProbe, ownChangeCounts: [Int]) {
    let snapshot = PasteboardSnapshot.take(pasteboard)
    let before = pasteboard.changeCount
    postCopy()
    let deadline = ContinuousClock.now + Self.copyWait
    while pasteboard.changeCount == before, ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(10))
    }
    guard pasteboard.changeCount != before else { return (.copiedNothing, []) }
    for _ in 0..<5 {
      let seen = pasteboard.changeCount
      try? await Task.sleep(for: Self.settle)
      if pasteboard.changeCount == seen { break }
    }
    let text = pasteboard.string(forType: .string)
    let restored = snapshot.restore(to: pasteboard)
    let counts = Array((before + 1)...restored)
    guard let text, !text.allSatisfy(\.isWhitespace) else { return (.copiedNothing, counts) }
    return (.text(text), counts)
  }
}

import AppKit
import Carbon.HIToolbox
import ThoughtsCore

@MainActor
protocol SelectionReading: AnyObject {
  var secureInputOn: Bool { get }
  func probe(pid: Int32) async -> SelectionProbe
  func copySelection() async -> (SelectionProbe, ownChangeCounts: [Int])
}

enum CopyKeyCode {
  static let fallback = CGKeyCode(kVK_ANSI_C)

  static func find(translate: (CGKeyCode) -> String?) -> CGKeyCode {
    if translate(fallback) == "c" { return fallback }
    return (0..<128).map { CGKeyCode($0) }.first { translate($0) == "c" } ?? fallback
  }

  @MainActor
  static func current() -> CGKeyCode {
    guard let layout = commandLayout() else { return fallback }
    return find { translate($0, layout: layout) }
  }

  static func commandLayout() -> CFData? {
    guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
      let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else { return nil }
    return Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
  }

  static func translate(_ code: CGKeyCode, layout: CFData) -> String? {
    guard let bytes = CFDataGetBytePtr(layout) else { return nil }
    var dead: UInt32 = 0
    var length = 0
    var characters = [UniChar](repeating: 0, count: 4)
    let status = bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) {
      UCKeyTranslate(
        $0, UInt16(code), UInt16(kUCKeyActionDown), UInt32((cmdKey >> 8) & 0xFF),
        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead,
        characters.count, &length, &characters)
    }
    guard status == noErr, length > 0 else { return nil }
    return String(utf16CodeUnits: characters, count: length)
  }
}

enum CopyKeyPoster {
  @MainActor
  static func post() {
    guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
    let source = CGEventSource(stateID: .privateState)
    let code = CopyKeyCode.current()
    for keyDown in [true, false] {
      guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: keyDown)
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
  private let secureInput: @MainActor () -> Bool

  init(
    pasteboard: NSPasteboard = .general,
    readSelection: @escaping @Sendable (Int32) -> SelectionProbe = { _ in .unavailable },
    postCopy: @escaping @MainActor () -> Void = CopyKeyPoster.post,
    secureInput: @escaping @MainActor () -> Bool = { IsSecureEventInputEnabled() }
  ) {
    self.pasteboard = pasteboard
    self.readSelection = readSelection
    self.postCopy = postCopy
    self.secureInput = secureInput
  }

  var secureInputOn: Bool { secureInput() }

  func probe(pid: Int32) async -> SelectionProbe {
    let readSelection = readSelection
    return await Task.detached { readSelection(pid) }.value
  }

  func copySelection() async -> (SelectionProbe, ownChangeCounts: [Int]) {
    if secureInput() { return (.copiedNothing, []) }
    if ClipboardTypes.isConcealedOrTransient((pasteboard.types ?? []).map(\.rawValue)) {
      return (.copiedNothing, [])
    }
    let read = PasteboardRead(pasteboard: pasteboard)
    let snapshot = await read.run { PasteboardSnapshot.take($0) }
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
    let copied = pasteboard.changeCount
    let concealed = ClipboardTypes.isConcealed((pasteboard.types ?? []).map(\.rawValue))
    let text = concealed ? nil : await read.run { $0.string(forType: .string) }
    let restored = snapshot.restore(to: pasteboard)
    let counts = [copied, restored]
    if concealed { return (.secureField, counts) }
    guard let text, !text.allSatisfy(\.isWhitespace) else { return (.copiedNothing, counts) }
    return (.text(text), counts)
  }
}

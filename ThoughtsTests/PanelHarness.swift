import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

enum KeyWindowSeam {
  private static let selector = NSSelectorFromString("_keyWindow")
  private static let activeSelector = NSSelectorFromString("_hasActiveAppearance")
  nonisolated(unsafe) private static var original: IMP?
  nonisolated(unsafe) private static var originalActive: IMP?
  nonisolated(unsafe) private static var window: NSWindow?

  private typealias Getter = @convention(c) (AnyObject, Selector) -> Unmanaged<NSWindow>?
  private typealias Flag = @convention(c) (AnyObject, Selector) -> Bool

  @MainActor
  static func install(_ target: NSWindow) throws {
    let method = try #require(class_getInstanceMethod(NSApplication.self, selector))
    let active = try #require(class_getInstanceMethod(type(of: target), activeSelector))
    window = target
    guard original == nil else { return }
    original = method_getImplementation(method)
    let block: @convention(block) (AnyObject) -> AnyObject? = { _ in window }
    method_setImplementation(method, imp_implementationWithBlock(block))
    let activeOriginal = method_getImplementation(active)
    originalActive = activeOriginal
    let flag = unsafeBitCast(activeOriginal, to: Flag.self)
    let activeBlock: @convention(block) (AnyObject) -> Bool = { this in
      this === window || flag(this, activeSelector)
    }
    method_setImplementation(active, imp_implementationWithBlock(activeBlock))
  }

  @MainActor
  static func remove() {
    let target = window
    window = nil
    if let originalActive, let target,
      let active = class_getInstanceMethod(type(of: target), activeSelector)
    {
      method_setImplementation(active, originalActive)
      self.originalActive = nil
    }
    guard let original, let method = class_getInstanceMethod(NSApplication.self, selector)
    else { return }
    method_setImplementation(method, original)
    self.original = nil
  }

  @MainActor
  static var appKitKeyWindow: NSWindow? {
    guard let method = class_getInstanceMethod(NSApplication.self, selector) else { return nil }
    let getter = unsafeBitCast(original ?? method_getImplementation(method), to: Getter.self)
    return getter(NSApp, selector)?.takeUnretainedValue()
  }
}

@MainActor
final class PanelHarness {
  enum Key {
    case up
    case down
    case returnKey
    case escape
    case delete
    case space
    case character(Character)

    var code: UInt16 {
      switch self {
      case .up: 126
      case .down: 125
      case .returnKey: 36
      case .escape: 53
      case .delete: 51
      case .space: 49
      case .character(let character):
        Self.letterCodes[Character(character.lowercased())] ?? 0
      }
    }

    var characters: String {
      switch self {
      case .up: "\u{F700}"
      case .down: "\u{F701}"
      case .returnKey: "\r"
      case .escape: "\u{1B}"
      case .delete: "\u{7F}"
      case .space: " "
      case .character(let character): String(character)
      }
    }

    private static let letterCodes: [Character: UInt16] = [
      "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
      "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35,
      "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, " ": 49,
    ]
  }

  let fixture: ListFixture
  let panel: ThoughtsPanel
  let hosting: NSHostingView<PanelRootView>
  let actions: ThoughtActions
  let board: NSPasteboard
  let trash: FakeTrash
  let opener = OpenerLog()
  private(set) var hideRequests = 0
  private(set) var historySteps: [HistoryDirection] = []
  private(set) var seenKeyDowns = 0
  private(set) var foreignKeys = 0
  private(set) var keyChanges = 0
  private(set) var activations = 0
  private let frontmost: NSRunningApplication?
  private var posted: Set<TimeInterval> = []
  private var lastStamp: TimeInterval = 0
  private var drained: Set<Int> = []
  private var token = 0
  private var monitors: [Any] = []
  private var observers: [any NSObjectProtocol] = []
  private static let sentinel: Int16 = 7193
  private static var busy = false

  var list: ListModel { fixture.model }
  var input: InputModel { fixture.input }

  static func run(_ body: (PanelHarness) async throws -> Void) async throws {
    while busy { try await Task.sleep(for: .milliseconds(20)) }
    busy = true
    defer { busy = false }
    let harness = try PanelHarness()
    do {
      try await body(harness)
    } catch {
      harness.close()
      throw error
    }
    harness.close()
    harness.verifyIsolation()
  }

  private init() throws {
    fixture = try ListFixture()
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let preferences = Preferences(defaults: defaults)
    let list = fixture.model
    let input = fixture.input
    hosting = NSHostingView(
      rootView: PanelRootView(preferences: preferences, list: list, input: input))
    hosting.sizingOptions = []
    let content = DropDestinationView(content: hosting)
    panel = ThoughtsPanel(content: content)
    panel.setContentSize(NSSize(width: PanelController.width, height: PanelController.maxHeight))
    hosting.layoutSubtreeIfNeeded()
    board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    panel.pasteboard = board
    trash = FakeTrash(folder: fixture.root.appendingPathComponent("Trash"))
    let trash = trash
    let actions = ThoughtActions(
      list: list, location: fixture.location, pasteboard: PasteboardWriter(pasteboard: board),
      opener: opener.opener, trash: { try trash.move($0) },
      undoManager: panel.sharedUndoManager)
    self.actions = actions
    frontmost = NSWorkspace.shared.frontmostApplication
    panel.onNothingToDo = { [actions] in actions.nothingToDo($0) }
    panel.defersHistory = { [weak self, actions] direction in
      self?.historySteps.append(direction)
      return actions.deferIfBusy(direction)
    }
    panel.onPaste = { [list, input] pasteboard in
      list.focus == .input && input.takeImage(from: pasteboard)
    }
    list.onCommand = { [weak self, actions, input] command in
      switch command {
      case .hidePanel: self?.hideRequests += 1
      case .add: Task { await input.submit() }
      case .removeAttachment: input.removeAttachment()
      case .type(let text): input.text += text
      default: break
      }
      actions.perform(command)
    }
    watch()
  }

  private func watch() {
    let keys = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
      MainActor.assumeIsolated { self?.noteKey(event) }
      return event
    }
    let sentinels = NSEvent.addLocalMonitorForEvents(matching: .applicationDefined) {
      [weak self] event in
      if event.subtype.rawValue == Self.sentinel {
        let token = event.data1
        MainActor.assumeIsolated { _ = self?.drained.insert(token) }
      }
      return event
    }
    monitors = [keys, sentinels].compactMap { $0 }
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) {
        [weak self] _ in MainActor.assumeIsolated { self?.keyChanges += 1 }
      },
      center.addObserver(
        forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
      ) { [weak self] _ in MainActor.assumeIsolated { self?.activations += 1 } },
    ]
  }

  private func noteKey(_ event: NSEvent) {
    if event.type == .keyDown { seenKeyDowns += 1 }
    if !posted.contains(where: { abs($0 - event.timestamp) < 0.000_000_5 }) { foreignKeys += 1 }
  }

  static func offscreenFrame() -> CGRect {
    let union = NSScreen.screens.map(\.frame).reduce(CGRect.null) { $0.union($1) }
    return CGRect(
      x: union.maxX + 4000, y: union.minY, width: PanelController.width,
      height: PanelController.maxHeight)
  }

  func show() async throws {
    list.focus = list.editing == nil ? .input : .edit
    if list.editing == nil { list.selection = [] }
    list.now = ListFixture.now
    list.panelDidShow()
    panel.setFrame(Self.offscreenFrame(), display: false)
    panel.orderFrontRegardless()
    try KeyWindowSeam.install(panel)
    await settle()
  }

  func seed(_ texts: [String]) throws {
    for (offset, text) in texts.enumerated() {
      try fixture.addText(text, daysAgo: Double(texts.count - offset))
    }
    try fixture.reload()
  }

  func press(_ key: Key, _ flags: NSEvent.ModifierFlags = []) async {
    post(key, flags)
    await drain()
  }

  func type(_ text: String) async {
    for character in text {
      post(.character(character), character.isUppercase ? .shift : [])
    }
    await drain()
  }

  func post(_ key: Key, _ flags: NSEvent.ModifierFlags = []) {
    for kind in [NSEvent.EventType.keyDown, .keyUp] {
      guard
        let event = NSEvent.keyEvent(
          with: kind, location: .zero, modifierFlags: flags, timestamp: nextStamp(),
          windowNumber: panel.windowNumber, context: nil, characters: key.characters,
          charactersIgnoringModifiers: key.characters, isARepeat: false, keyCode: key.code)
      else { continue }
      NSApp.postEvent(event, atStart: false)
    }
  }

  func keyEvent(_ key: Key, _ flags: NSEvent.ModifierFlags = []) -> NSEvent? {
    NSEvent.keyEvent(
      with: .keyDown, location: .zero, modifierFlags: flags, timestamp: nextStamp(),
      windowNumber: panel.windowNumber, context: nil, characters: key.characters,
      charactersIgnoringModifiers: key.characters, isARepeat: false, keyCode: key.code)
  }

  private func nextStamp() -> TimeInterval {
    let stamp = max(ProcessInfo.processInfo.systemUptime, lastStamp + 0.000_001)
    lastStamp = stamp
    posted.insert(stamp)
    return stamp
  }

  func drain(settling: Duration = .milliseconds(400)) async {
    token += 1
    let current = token
    if let event = NSEvent.otherEvent(
      with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0,
      windowNumber: 0, context: nil, subtype: Self.sentinel, data1: current, data2: 0)
    {
      NSApp.postEvent(event, atStart: false)
    }
    for _ in 0..<400 where !drained.contains(current) {
      try? await Task.sleep(for: .milliseconds(5))
    }
    #expect(drained.contains(current))
    await settle(settling)
  }

  func settle(_ duration: Duration = .milliseconds(400)) async {
    try? await Task.sleep(for: duration)
  }

  var inputField: InputTextField? {
    PasteFieldTests.inputFields(in: hosting).first
  }

  var firstResponderText: String? {
    (panel.firstResponder as? NSTextView)?.string
  }

  var storedTexts: [String] {
    get throws {
      try fixture.store.entries().compactMap(\.thought).compactMap {
        if case .text(let text) = $0.content { text } else { nil }
      }
    }
  }

  func snapshot(_ name: String, appearance: NSAppearance.Name = .aqua) throws -> URL {
    hosting.appearance = NSAppearance(named: appearance)
    return try SnapshotRenderer.render(view: hosting, name: name)
  }

  private func close() {
    panel.makeFirstResponder(nil)
    KeyWindowSeam.remove()
    panel.orderOut(nil)
    for monitor in monitors { NSEvent.removeMonitor(monitor) }
    monitors = []
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers = []
    board.releaseGlobally()
  }

  private func verifyIsolation() {
    let front = NSWorkspace.shared.frontmostApplication
    #expect(
      front?.processIdentifier == frontmost?.processIdentifier,
      "front app went from \(frontmost?.bundleIdentifier ?? "none") to \(front?.bundleIdentifier ?? "none")"
    )
    #expect(!NSApp.isActive)
    #expect(KeyWindowSeam.appKitKeyWindow == nil)
    #expect(keyChanges == 0)
    #expect(activations == 0)
    #expect(foreignKeys == 0)
    #expect(Self.ownWindowsOnScreens().isEmpty)
  }

  static func ownWindowsOnScreens() -> [CGRect] {
    let pid = ProcessInfo.processInfo.processIdentifier
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &displays, &count)
    let screens = displays.map(CGDisplayBounds)
    let windows =
      CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return windows.compactMap { info -> CGRect? in
      guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
        let bounds = info[kCGWindowBounds as String] as? NSDictionary,
        let rect = CGRect(dictionaryRepresentation: bounds),
        screens.contains(where: { $0.intersects(rect) })
      else { return nil }
      return rect
    }
  }
}

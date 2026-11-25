import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
final class PanelHarness {
  enum Key {
    case up
    case down
    case returnKey
    case escape
    case delete
    case space
    case tab
    case character(Character)

    var code: UInt16? {
      switch self {
      case .up: 126
      case .down: 125
      case .returnKey: 36
      case .escape: 53
      case .delete: 51
      case .space: 49
      case .tab: 48
      case .character(let character): Self.letterCodes[Character(character.lowercased())]
      }
    }

    var deviceFlags: NSEvent.ModifierFlags {
      switch self {
      case .up, .down: [.function, .numericPad]
      default: []
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
      case .tab: "\t"
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
  private(set) var isolationChecks = 0
  private(set) var submitting = 0
  let startedActive: Bool
  private let startedFront: Bool
  private let host = Bundle.main.bundleIdentifier ?? "the test host"
  private let hostPID = ProcessInfo.processInfo.processIdentifier
  private var posted: Set<TimeInterval> = []
  private var lastStamp: TimeInterval = 0
  private var drained: Set<Int> = []
  private var token = 0
  private var monitors: [Any] = []
  private var observers: [any NSObjectProtocol] = []
  private static let sentinel: Int16 = 7193
  private static let quiet: Duration = .milliseconds(250)
  private static let settleBound: Duration = .seconds(2)
  private static var busy = false

  var list: ListModel { fixture.model }
  var input: InputModel { fixture.input }

  static func run(
    laidOut: Bool = true, _ body: (PanelHarness) async throws -> Void
  ) async throws {
    while busy { try await Task.sleep(for: .milliseconds(20)) }
    busy = true
    defer { busy = false }
    let harness = try PanelHarness(laidOut: laidOut)
    do {
      try await body(harness)
    } catch {
      harness.close()
      throw error
    }
    harness.close()
    harness.verifyIsolation()
  }

  private init(laidOut: Bool) throws {
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
    if laidOut {
      panel.setContentSize(
        NSSize(width: PanelController.width, height: PanelController.maxHeight))
      hosting.layoutSubtreeIfNeeded()
    }
    board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    panel.pasteboard = board
    trash = FakeTrash(folder: fixture.root.appendingPathComponent("Trash"))
    let trash = trash
    let actions = ThoughtActions(
      list: list, location: fixture.location, pasteboard: PasteboardWriter(pasteboard: board),
      opener: opener.opener, trash: { try trash.move($0) },
      undoManager: panel.sharedUndoManager)
    self.actions = actions
    startedActive = NSApp.isActive
    startedFront =
      NSWorkspace.shared.frontmostApplication?.processIdentifier
      == ProcessInfo.processInfo.processIdentifier
    panel.onCancel = { [weak self] in self?.hideRequests += 1 }
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
      case .add:
        self?.submitting += 1
        Task {
          await input.submit()
          self?.submitting -= 1
        }
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
    await settle("after show")
  }

  func seed(_ texts: [String]) throws {
    for (offset, text) in texts.enumerated() {
      try fixture.addText(text, daysAgo: Double(texts.count - offset))
    }
    try fixture.reload()
  }

  func press(_ key: Key, _ flags: NSEvent.ModifierFlags = []) async {
    post(key, flags)
    await drain("after pressing \(key)")
  }

  func type(_ text: String) async {
    for character in text {
      post(.character(character), character.isUppercase ? .shift : [])
    }
    await drain("after typing \(text)")
  }

  func endEventUndoGroup() {
    _ = (UndoManager.self as AnyObject).perform(Selector(("_endTopLevelGroupings")))
    #expect(panel.sharedUndoManager.groupingLevel == 0, "an undo group stayed open")
  }

  func post(_ key: Key, _ flags: NSEvent.ModifierFlags = []) {
    for kind in [NSEvent.EventType.keyDown, .keyUp] {
      guard let event = keyEvent(key, flags, kind: kind) else { return }
      NSApp.postEvent(event, atStart: false)
    }
  }

  func keyEvent(
    _ key: Key, _ flags: NSEvent.ModifierFlags = [], kind: NSEvent.EventType = .keyDown
  ) -> NSEvent? {
    guard let code = key.code else {
      Issue.record("the harness has no key code for \(key)")
      return nil
    }
    return NSEvent.keyEvent(
      with: kind, location: .zero, modifierFlags: flags.union(key.deviceFlags),
      timestamp: nextStamp(), windowNumber: panel.windowNumber, context: nil,
      characters: key.characters, charactersIgnoringModifiers: key.characters, isARepeat: false,
      keyCode: code)
  }

  private func nextStamp() -> TimeInterval {
    let stamp = max(ProcessInfo.processInfo.systemUptime, lastStamp + 0.000_001)
    lastStamp = stamp
    posted.insert(stamp)
    return stamp
  }

  func drain(_ step: String) async {
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
    #expect(drained.contains(current), "the posted events never drained \(step)")
    await settle(step)
  }

  func settle(_ step: String = "after settling") async {
    let clock = ContinuousClock()
    let deadline = clock.now + Self.settleBound
    var last = fingerprint
    var quietSince = clock.now
    while clock.now - quietSince < Self.quiet, clock.now < deadline {
      try? await Task.sleep(for: .milliseconds(10))
      let current = fingerprint
      if current != last {
        last = current
        quietSince = clock.now
      }
    }
    #expect(clock.now - quietSince >= Self.quiet, "the panel kept changing for 2 s \(step)")
    checkIsolation(step)
  }

  func submitted() async {
    let deadline = ContinuousClock.now + Self.settleBound
    while submitting > 0, ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(10))
    }
    #expect(submitting == 0, "a submit was still running after 2 s")
  }

  private var fingerprint: String {
    let editor = panel.firstResponder as? NSTextView
    return [
      "\(list.focus)", "\(list.selection)", "\(list.isMenuOpen)", "\(list.menuHighlight)",
      list.query, "\(list.editing != nil)", list.editText, list.feedback?.text ?? "",
      "\(list.visible.map(\.fileName))", input.text,
      panel.firstResponder.map { "\(ObjectIdentifier($0))" } ?? "none", editor?.string ?? "",
      "\(editor?.selectedRange() ?? NSRange())",
    ].joined(separator: "|")
  }

  var inputField: InputTextField? {
    PasteFieldTests.inputFields(in: hosting).first
  }

  func field<Field: NSTextField>(_ type: Field.Type) -> Field? {
    Self.views(of: type, in: hosting).first
  }

  func isEditing(_ field: NSTextField?) -> Bool {
    guard let editor = field?.currentEditor() else { return false }
    return panel.firstResponder === editor
  }

  var listScroller: NSScrollView? {
    Self.views(of: NSScrollView.self, in: hosting).max { $0.frame.height < $1.frame.height }
  }

  func isScrolledToBottom(_ scroller: NSScrollView) -> Bool {
    guard let document = scroller.documentView else { return false }
    let visible = scroller.documentVisibleRect
    let bottom = document.isFlipped ? document.bounds.maxY - visible.maxY : visible.minY
    return abs(bottom) < 1
  }

  func caretIsVisible() -> Bool {
    guard let editor = panel.firstResponder as? NSTextView else { return false }
    let screen = editor.firstRect(forCharacterRange: editor.selectedRange(), actualRange: nil)
    let caret = editor.convert(panel.convertFromScreen(screen), from: nil)
    guard let clip = editor.enclosingScrollView?.contentView ?? editor.superview else {
      return false
    }
    let shown = editor.convert(clip.bounds, from: clip)
    return shown.insetBy(dx: -1, dy: -1).contains(NSPoint(x: shown.midX, y: caret.midY))
  }

  static func views<Found: NSView>(of type: Found.Type, in view: NSView) -> [Found] {
    view.subviews.flatMap { sub in
      (sub as? Found).map { [$0] + views(of: type, in: sub) } ?? views(of: type, in: sub)
    }
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

  func checkIsolation(_ step: String) {
    isolationChecks += 1
    let front = NSWorkspace.shared.frontmostApplication
    let shown = front?.bundleIdentifier ?? "no app"
    if !startedFront {
      #expect(front?.processIdentifier != hostPID, "\(host) became the front app \(step)")
    }
    #expect(
      NSApp.isActive == startedActive,
      "\(host) went from \(startedActive ? "active" : "inactive") \(step) with \(shown) in front")
    #expect(
      KeyWindowSeam.appKitKeyWindow == nil,
      "AppKit gave \(host) a key window \(step) with \(shown) in front")
    #expect(keyChanges == 0, "a window of \(host) became key \(step) with \(shown) in front")
    #expect(activations == 0, "\(host) became active \(step) with \(shown) in front")
    #expect(Self.ownWindowsOnScreens().isEmpty, "a window of \(host) showed on a screen \(step)")
  }

  private func verifyIsolation() {
    checkIsolation("after the run")
    #expect(foreignKeys == 0, "keys from outside the harness reached \(host)")
  }

  static func waitUntil(within limit: Duration = .seconds(5), _ condition: () -> Bool) async
    -> Bool
  {
    let deadline = ContinuousClock.now + limit
    while !condition() {
      guard ContinuousClock.now < deadline else { return false }
      try? await Task.sleep(for: .milliseconds(10))
    }
    return true
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

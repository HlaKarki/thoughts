import AppKit

enum PanelShowPlan: Equatable {
  case fresh
  case refocus
  case moveAndRefocus(CGRect)
}

enum MenuCloseOutcome: Equatable {
  case none
  case restoreKey
  case hide
}

struct LostKeyTracker: Equatable {
  private var event: Int?

  var held: Bool { event != nil }

  mutating func lostKey(toEvent number: Int?) {
    event = number
  }

  mutating func menuOpened(event number: Int?, isShown: Bool, isKey: Bool) {
    guard held, isShown, !isKey, number == event else {
      event = nil
      return
    }
  }

  mutating func clear() {
    event = nil
  }
}

@MainActor
final class PanelController {
  static let width: CGFloat = 360
  static let maxHeight: CGFloat = 812
  static let edgeInset: CGFloat = 16
  static let duration: TimeInterval = 0.2

  private let panel: ThoughtsPanel
  private let preferences: Preferences
  private let screens: @MainActor () -> [(frame: CGRect, visible: CGRect)]
  private var hiding = false
  private var transition = 0
  var ownIconInUse: @MainActor () -> Bool = { false }
  private var lostKey = LostKeyTracker()
  var onWillShow: (() -> Void)?
  var onWillHide: (() -> Void)?
  var onEdgeMove: (() -> Void)?
  private(set) var restingFrame: CGRect?

  init(
    content: NSView, preferences: Preferences,
    screens: @escaping @MainActor () -> [(frame: CGRect, visible: CGRect)] = {
      NSScreen.screens.map { ($0.frame, $0.visibleFrame) }
    }
  ) {
    self.panel = ThoughtsPanel(content: content)
    self.preferences = preferences
    self.screens = screens
    panel.onCancel = { [weak self] in self?.hide() }
    NotificationCenter.default.addObserver(
      forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.resignedKey() }
    }
    followEdge()
  }

  var onPaste: ((NSPasteboard) -> Bool)? {
    get { panel.onPaste }
    set { panel.onPaste = newValue }
  }

  var onOpenSettings: (() -> Void)? {
    get { panel.onOpenSettings }
    set { panel.onOpenSettings = newValue }
  }

  var undoManager: UndoManager { panel.sharedUndoManager }

  var onNothingToDo: ((HistoryDirection) -> Void)? {
    get { panel.onNothingToDo }
    set { panel.onNothingToDo = newValue }
  }

  var defersHistory: ((HistoryDirection) -> Bool)? {
    get { panel.defersHistory }
    set { panel.defersHistory = newValue }
  }

  var frame: CGRect { panel.frame }
  var edge: PanelEdge { preferences.edge }

  var isShown: Bool { panel.isVisible && !hiding }

  static func frame(in visible: CGRect, edge: PanelEdge) -> CGRect {
    let height = min(maxHeight, visible.height - 2 * edgeInset)
    let x =
      switch edge {
      case .left: visible.minX + edgeInset
      case .right: visible.maxX - edgeInset - width
      }
    return CGRect(x: x, y: visible.midY - height / 2, width: width, height: height)
  }

  static func showPlan(
    isShown: Bool, panelFrame: CGRect, requestedVisible: CGRect?, edge: PanelEdge
  ) -> PanelShowPlan {
    guard isShown else { return .fresh }
    guard let visible = requestedVisible,
      !visible.contains(CGPoint(x: panelFrame.midX, y: panelFrame.midY))
    else { return .refocus }
    return .moveAndRefocus(frame(in: visible, edge: edge))
  }

  static func afterMenuClosed(
    pick: MenuPick, lostKeyToOwnIcon: Bool, keepOpen: Bool
  ) -> MenuCloseOutcome {
    switch pick {
    case .show: .none
    case .other: keepOpen ? .none : .hide
    case .none: lostKeyToOwnIcon ? .restoreKey : .none
    }
  }

  static func mouseEventNumber(_ event: NSEvent?) -> Int? {
    guard let event else { return nil }
    switch event.type {
    case .leftMouseDown, .rightMouseDown, .otherMouseDown: return event.eventNumber
    default: return nil
    }
  }

  static func hidesOnKeyLoss(keepOpen: Bool, ownIconInUse: Bool) -> Bool {
    !keepOpen && !ownIconInUse
  }

  static func offscreenFrame(from frame: CGRect, edge: PanelEdge) -> CGRect {
    let travel = width + edgeInset
    return frame.offsetBy(dx: edge == .right ? travel : -travel, dy: 0)
  }

  func show(on screen: NSScreen? = nil) {
    present(makeKey: true, visible: screen?.visibleFrame)
  }

  func show(inVisible visible: CGRect, makeKey: Bool) {
    present(makeKey: makeKey, visible: visible)
  }

  func showForDrag() {
    present(makeKey: false, visible: nil)
  }

  func makeKey() {
    panel.makeKeyAndOrderFront(nil)
  }

  private func present(makeKey: Bool, visible: CGRect?) {
    lostKey.clear()
    if isShown {
      if makeKey { refocus(on: visible) }
      return
    }
    onWillShow?()
    transition += 1
    hiding = false
    let target = Self.frame(
      in: visible ?? screenUnderPointer().visibleFrame, edge: preferences.edge)
    restingFrame = target
    if reduceMotion {
      panel.setFrame(target, display: false)
      panel.alphaValue = 0
    } else {
      panel.setFrame(Self.offscreenFrame(from: target, edge: preferences.edge), display: false)
      panel.alphaValue = 0
    }
    if makeKey {
      panel.makeKeyAndOrderFront(nil)
    } else {
      panel.orderFrontRegardless()
    }
    animate(frame: target, alpha: 1, completion: nil)
  }

  private func refocus(on visible: CGRect?) {
    let plan = Self.showPlan(
      isShown: true, panelFrame: panel.frame, requestedVisible: visible, edge: preferences.edge)
    onWillShow?()
    panel.makeKeyAndOrderFront(nil)
    guard case .moveAndRefocus(let target) = plan else { return }
    restingFrame = target
    animate(frame: target, alpha: 1, completion: nil)
  }

  func ownMenuOpened() {
    lostKey.menuOpened(
      event: Self.mouseEventNumber(NSApp.currentEvent), isShown: isShown, isKey: panel.isKeyWindow)
  }

  func ownMenuClosed(_ pick: MenuPick) {
    let lost = lostKey.held
    lostKey.clear()
    guard isShown else { return }
    let outcome = Self.afterMenuClosed(
      pick: pick, lostKeyToOwnIcon: lost, keepOpen: preferences.keepOpen)
    switch outcome {
    case .none: break
    case .restoreKey: panel.makeKeyAndOrderFront(nil)
    case .hide: hide()
    }
  }

  func hide() {
    guard isShown else { return }
    lostKey.clear()
    onWillHide?()
    hiding = true
    let base = restingFrame ?? panel.frame
    restingFrame = nil
    transition += 1
    let current = transition
    let target =
      reduceMotion ? panel.frame : Self.offscreenFrame(from: base, edge: preferences.edge)
    animate(frame: target, alpha: 0) { [weak self] in
      guard let self, self.transition == current else { return }
      self.panel.orderOut(nil)
      self.hiding = false
    }
  }

  private func followEdge() {
    withObservationTracking {
      _ = preferences.edge
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.moveToEdge()
        self.followEdge()
      }
    }
  }

  private func moveToEdge() {
    guard isShown, let resting = restingFrame,
      let visible = PreviewWindowController.visibleFrame(for: resting, among: screens())
    else { return }
    let target = Self.frame(in: visible, edge: preferences.edge)
    guard target != resting else { return }
    transition += 1
    restingFrame = target
    if reduceMotion {
      panel.setFrame(target, display: true)
    } else {
      animate(frame: target, alpha: 1, completion: nil)
    }
    onEdgeMove?()
  }

  private var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  private func resignedKey() {
    guard isShown else { return }
    let ownIcon = ownIconInUse()
    if ownIcon { lostKey.lostKey(toEvent: Self.mouseEventNumber(NSApp.currentEvent)) }
    guard Self.hidesOnKeyLoss(keepOpen: preferences.keepOpen, ownIconInUse: ownIcon) else {
      return
    }
    hide()
  }

  private func screenUnderPointer() -> NSScreen {
    let pointer = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) }
      ?? NSScreen.main ?? NSScreen.screens[0]
  }

  private func animate(frame: CGRect, alpha: CGFloat, completion: (@MainActor () -> Void)?) {
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = Self.duration
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        panel.animator().setFrame(frame, display: true)
        panel.animator().alphaValue = alpha
      },
      completionHandler: {
        MainActor.assumeIsolated { completion?() }
      })
  }
}

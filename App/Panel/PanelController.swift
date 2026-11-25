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
  nonisolated static let width: CGFloat = 360
  nonisolated static let maxHeight: CGFloat = 640
  nonisolated static let edgeInset: CGFloat = 16
  nonisolated static let snapDistance: CGFloat = 40
  static let duration: TimeInterval = 0.2

  let panel: ThoughtsPanel
  private let preferences: Preferences
  private let visibility: AppVisibility
  private let key: WindowKey
  private let screens: @MainActor () -> [ScreenFrames]
  private let reducesMotion: @MainActor () -> Bool
  private var hiding = false
  private var transition = 0
  var ownIconInUse: @MainActor () -> Bool = { false }
  private var lostKey = LostKeyTracker()
  var onWillShow: (() -> Void)?
  var onWillRefocus: (() -> Void)?
  var onWillHide: (() -> Void)?
  var onMove: (() -> Void)?
  private(set) var restingFrame: CGRect?

  init(
    content: NSView, preferences: Preferences,
    screens: @escaping @MainActor () -> [ScreenFrames] = ScreenList.live,
    visibility: AppVisibility = .live,
    key: WindowKey = .live,
    reducesMotion: @escaping @MainActor () -> Bool = {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
  ) {
    self.panel = ThoughtsPanel(content: content)
    self.reducesMotion = reducesMotion
    self.preferences = preferences
    self.visibility = visibility
    self.key = key
    self.screens = screens
    panel.onCancel = { [weak self] in self?.hide() }
    panel.onDragStart = { [weak self] in self?.isShown == true }
    panel.onDragEnd = { [weak self] in self?.dragEnded() }
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
  var isVisible: Bool { panel.isVisible }
  var edge: PanelEdge { preferences.edge }

  var isShown: Bool { panel.isVisible && !hiding }
  var isKey: Bool { key.isKey(panel) }
  var keepsOpen: Bool { preferences.keepOpen }

  func frame(onVisible visible: CGRect) -> CGRect {
    Self.frame(in: visible, edge: preferences.edge, position: preferences.panelPosition)
  }

  static func showPlan(
    isShown: Bool, panelFrame: CGRect, requestedVisible: CGRect?, edge: PanelEdge,
    position: PanelPosition? = nil
  ) -> PanelShowPlan {
    guard isShown else { return .fresh }
    guard let visible = requestedVisible,
      !visible.contains(CGPoint(x: panelFrame.midX, y: panelFrame.midY))
    else { return .refocus }
    return .moveAndRefocus(frame(in: visible, edge: edge, position: position))
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
    visibility.revealBeforeOrderingFront()
    key.makeKey(panel)
  }

  private func present(makeKey: Bool, visible: CGRect?) {
    lostKey.clear()
    if isShown {
      if makeKey { refocus(on: visible) }
      return
    }
    guard let screen = visible ?? screenUnderPointer() else { return }
    onWillShow?()
    transition += 1
    hiding = false
    let target = frame(onVisible: screen)
    restingFrame = target
    let start = slideEdge(of: target, in: screen).map {
      Self.offscreenFrame(from: target, edge: $0)
    }
    panel.setFrameAtOnce(start ?? target, display: false)
    panel.alphaValue = 0
    visibility.revealBeforeOrderingFront()
    if makeKey {
      key.makeKey(panel)
    } else {
      panel.orderFrontRegardless()
    }
    animate(frame: target, alpha: 1, completion: nil)
  }

  private func refocus(on visible: CGRect?) {
    let plan = Self.showPlan(
      isShown: true, panelFrame: panel.frame, requestedVisible: visible, edge: preferences.edge,
      position: preferences.panelPosition)
    onWillRefocus?()
    visibility.revealBeforeOrderingFront()
    key.makeKey(panel)
    guard case .moveAndRefocus(let target) = plan else { return }
    let from = restingFrame ?? panel.frame
    transition += 1
    restingFrame = target
    if ScreenList.movesOntoAnotherScreen(from: from, to: target, among: screens()) {
      panel.alphaValue = 0
      panel.setFrameAtOnce(target, display: true)
      animate(frame: target, alpha: 1, completion: nil)
    } else {
      place(target)
    }
    onMove?()
  }

  func ownMenuOpened() {
    lostKey.menuOpened(
      event: Self.mouseEventNumber(NSApp.currentEvent), isShown: isShown, isKey: isKey)
  }

  func ownMenuClosed(_ pick: MenuPick) {
    let lost = lostKey.held
    lostKey.clear()
    guard isShown else { return }
    let outcome = Self.afterMenuClosed(
      pick: pick, lostKeyToOwnIcon: lost, keepOpen: preferences.keepOpen)
    switch outcome {
    case .none: break
    case .restoreKey:
      visibility.revealBeforeOrderingFront()
      key.makeKey(panel)
    case .hide: hide()
    }
  }

  func hide() {
    guard isShown else { return }
    lostKey.clear()
    let dragged = panel.cancelDrag()
    onWillHide?()
    hiding = true
    let base = dragged ? panel.frame : restingFrame ?? panel.frame
    restingFrame = nil
    transition += 1
    let current = transition
    let side = ScreenList.visibleFrame(for: base, among: screens()).flatMap {
      slideEdge(of: base, in: $0)
    }
    let target = side.map { Self.offscreenFrame(from: base, edge: $0) } ?? base
    animate(frame: target, alpha: 0) { [weak self] in
      guard let self, self.transition == current else { return }
      self.panel.orderOut(nil)
      self.hiding = false
    }
  }

  private func dragEnded() {
    guard isShown, let visible = ScreenList.visibleFrame(for: panel.frame, among: screens())
    else { return }
    let target = Self.dropped(panel.frame, in: visible)
    transition += 1
    restingFrame = target
    preferences.panelPosition = PanelPosition(frame: target, in: visible)
    let edge = Self.edge(of: target, in: visible, current: preferences.edge)
    if edge != preferences.edge { preferences.edge = edge }
    place(target)
    onMove?()
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
    let edge = preferences.edge
    guard isShown, let resting = restingFrame,
      let visible = ScreenList.visibleFrame(for: resting, among: screens())
    else {
      if let position = preferences.panelPosition, position.moved(to: edge) != position {
        preferences.panelPosition = position.moved(to: edge)
      }
      onMove?()
      return
    }
    guard let position = preferences.panelPosition else {
      move(to: Self.frame(in: visible, edge: edge), from: resting)
      return
    }
    let target = Self.moved(resting, to: edge, in: visible)
    let moved = PanelPosition(frame: target, in: visible)
    if moved != position { preferences.panelPosition = moved }
    move(to: target, from: resting)
  }

  private func move(to target: CGRect, from resting: CGRect) {
    guard target != resting else { return }
    transition += 1
    restingFrame = target
    place(target)
    onMove?()
  }

  private func place(_ target: CGRect) {
    if reduceMotion {
      panel.setFrameAtOnce(target, display: true)
    } else {
      animate(frame: target, alpha: 1, completion: nil)
    }
  }

  private func slideEdge(of frame: CGRect, in visible: CGRect) -> PanelEdge? {
    reduceMotion
      ? nil
      : Self.slideEdge(of: frame, in: visible, preferring: preferences.edge, among: screens())
  }

  private var reduceMotion: Bool { reducesMotion() }

  private func resignedKey() {
    guard isShown else { return }
    let ownIcon = ownIconInUse()
    if ownIcon { lostKey.lostKey(toEvent: Self.mouseEventNumber(NSApp.currentEvent)) }
    guard Self.hidesOnKeyLoss(keepOpen: preferences.keepOpen, ownIconInUse: ownIcon) else {
      return
    }
    hide()
  }

  private func screenUnderPointer() -> CGRect? {
    let pointer = NSEvent.mouseLocation
    let list = screens()
    return (list.first { NSMouseInRect(pointer, $0.frame, false) } ?? list.first)?.visible
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

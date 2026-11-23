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

@MainActor
final class PanelController {
  static let width: CGFloat = 360
  static let maxHeight: CGFloat = 812
  static let edgeInset: CGFloat = 16
  static let duration: TimeInterval = 0.2

  private let panel: ThoughtsPanel
  private let preferences: Preferences
  private var hiding = false
  private var transition = 0
  var ownIconInUse: @MainActor () -> Bool = { false }
  private var lostKeyToOwnIcon = false
  var onWillShow: (() -> Void)?
  var onWillHide: (() -> Void)?
  var onDidChangeShown: (() -> Void)?
  private(set) var restingFrame: CGRect?

  init(content: NSView, preferences: Preferences) {
    self.panel = ThoughtsPanel(content: content)
    self.preferences = preferences
    panel.onCancel = { [weak self] in self?.hide() }
    NotificationCenter.default.addObserver(
      forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.resignedKey() }
    }
  }

  var onPaste: ((NSPasteboard) -> Bool)? {
    get { panel.onPaste }
    set { panel.onPaste = newValue }
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

  static func hidesOnKeyLoss(keepOpen: Bool, ownIconInUse: Bool) -> Bool {
    !keepOpen && !ownIconInUse
  }

  static func offscreenFrame(from frame: CGRect, edge: PanelEdge) -> CGRect {
    let travel = width + edgeInset
    return frame.offsetBy(dx: edge == .right ? travel : -travel, dy: 0)
  }

  func show(on screen: NSScreen? = nil) {
    present(makeKey: true, on: screen)
  }

  func showForDrag() {
    present(makeKey: false, on: nil)
  }

  func makeKey() {
    panel.makeKeyAndOrderFront(nil)
  }

  private func present(makeKey: Bool, on screen: NSScreen?) {
    if isShown {
      if makeKey { refocus(on: screen) }
      return
    }
    onWillShow?()
    transition += 1
    hiding = false
    let target = Self.frame(
      in: (screen ?? screenUnderPointer()).visibleFrame, edge: preferences.edge)
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
    onDidChangeShown?()
  }

  private func refocus(on screen: NSScreen?) {
    let plan = Self.showPlan(
      isShown: true, panelFrame: panel.frame, requestedVisible: screen?.visibleFrame,
      edge: preferences.edge)
    onWillShow?()
    panel.makeKeyAndOrderFront(nil)
    guard case .moveAndRefocus(let target) = plan else { return }
    restingFrame = target
    animate(frame: target, alpha: 1, completion: nil)
    onDidChangeShown?()
  }

  func ownMenuClosed(_ pick: MenuPick) {
    let lost = lostKeyToOwnIcon
    lostKeyToOwnIcon = false
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
    lostKeyToOwnIcon = false
    onWillHide?()
    hiding = true
    restingFrame = nil
    onDidChangeShown?()
    transition += 1
    let current = transition
    let target =
      reduceMotion
      ? panel.frame : Self.offscreenFrame(from: panel.frame, edge: preferences.edge)
    animate(frame: target, alpha: 0) { [weak self] in
      guard let self, self.transition == current else { return }
      self.panel.orderOut(nil)
      self.hiding = false
    }
  }

  private var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  private func resignedKey() {
    guard isShown else { return }
    let ownIcon = ownIconInUse()
    if ownIcon, !lostKeyToOwnIcon {
      lostKeyToOwnIcon = true
    }
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

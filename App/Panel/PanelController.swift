import AppKit

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
  var onWillShow: (() -> Void)?

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

  static func offscreenFrame(from frame: CGRect, edge: PanelEdge) -> CGRect {
    let travel = width + edgeInset
    return frame.offsetBy(dx: edge == .right ? travel : -travel, dy: 0)
  }

  func show() {
    guard !isShown else {
      panel.makeKeyAndOrderFront(nil)
      return
    }
    onWillShow?()
    transition += 1
    hiding = false
    let target = Self.frame(in: screenUnderPointer().visibleFrame, edge: preferences.edge)
    if reduceMotion {
      panel.setFrame(target, display: false)
      panel.alphaValue = 0
    } else {
      panel.setFrame(Self.offscreenFrame(from: target, edge: preferences.edge), display: false)
      panel.alphaValue = 0
    }
    panel.makeKeyAndOrderFront(nil)
    animate(frame: target, alpha: 1, completion: nil)
  }

  func hide() {
    guard isShown else { return }
    hiding = true
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

  func toggle() {
    if isShown { hide() } else { show() }
  }

  private var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  private func resignedKey() {
    guard isShown, !preferences.keepOpen else { return }
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

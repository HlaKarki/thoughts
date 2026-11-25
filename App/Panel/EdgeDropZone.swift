import AppKit

final class EdgeDropPanel: NSPanel {
  init(frame: CGRect, content: NSView) {
    super.init(
      contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: true)
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    isOpaque = false
    backgroundColor = NSColor.black.withAlphaComponent(0.01)
    hasShadow = false
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    animationBehavior = .none
    contentView = content
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class EdgeDropZone {
  static let thickness: CGFloat = 6
  static let hideDelay: Duration = .milliseconds(300)

  private let panel: PanelController
  private let preferences: Preferences
  private let monitor: DragSessionMonitor
  private let visibility: AppVisibility
  private let orderFront: @MainActor (NSWindow) -> Void
  private var window: EdgeDropPanel?
  private var shownByZone = false
  private var dropped = false
  var onTargetChange: (Bool) -> Void = { _ in }
  var onDrop: (NSPasteboard) -> Bool = { _ in false }

  init(
    panel: PanelController, preferences: Preferences, monitor: DragSessionMonitor,
    visibility: AppVisibility = .live,
    orderFront: @escaping @MainActor (NSWindow) -> Void = { $0.orderFrontRegardless() }
  ) {
    self.panel = panel
    self.preferences = preferences
    self.monitor = monitor
    self.visibility = visibility
    self.orderFront = orderFront
  }

  static func frame(screen: CGRect, visible: CGRect, edge: PanelEdge) -> CGRect {
    let x = edge == .right ? screen.maxX - thickness : screen.minX
    return CGRect(x: x, y: visible.minY, width: thickness, height: visible.height)
  }

  func start() {
    monitor.onStart = { [weak self] in self?.dragBegan() }
    monitor.onEnd = { [weak self] in self?.dragEnded() }
    monitor.start()
  }

  func noteDrop() {
    dropped = true
  }

  private func dragBegan() {
    guard !panel.isShown else { return }
    dropped = false
    shownByZone = false
    let pointer = NSEvent.mouseLocation
    guard
      let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) })
        ?? NSScreen.main
    else { return }
    let view = DropDestinationView()
    view.onEnter = { [weak self] in self?.entered() }
    view.onExit = { [weak self] in self?.onTargetChange(false) }
    view.onDrop = { [weak self] pasteboard in
      guard let self else { return false }
      noteDrop()
      onTargetChange(false)
      panel.makeKey()
      return onDrop(pasteboard)
    }
    let zone = EdgeDropPanel(
      frame: Self.frame(
        screen: screen.frame, visible: screen.visibleFrame, edge: preferences.edge),
      content: view)
    window = zone
    visibility.revealBeforeOrderingFront()
    orderFront(zone)
  }

  private func entered() {
    if !panel.isShown {
      panel.showForDrag()
      shownByZone = true
    }
    onTargetChange(true)
  }

  private func dragEnded() {
    window?.orderOut(nil)
    window = nil
    onTargetChange(false)
    guard shownByZone else { return }
    shownByZone = false
    Task { [weak self] in
      try? await Task.sleep(for: Self.hideDelay)
      guard let self, !dropped else { return }
      panel.hide()
    }
  }
}

import AppKit
import SwiftUI

final class ChipWindow: NSPanel {
  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true)
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    hidesOnDeactivate = false
    isMovable = false
    isReleasedWhenClosed = false
    animationBehavior = .none
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

final class ChipHostingView: NSHostingView<AnyView> {
  var onClick: (() -> Void)?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func mouseDown(with event: NSEvent) {
    guard let onClick else { return super.mouseDown(with: event) }
    onClick()
  }
}

@MainActor
final class EdgeChipPanel {
  static let edgeInset: CGFloat = 12
  static let bottomInset: CGFloat = 32
  static let panelGap: CGFloat = 12
  static let shadowMargin: CGFloat = 40
  static let duration: TimeInterval = 0.2
  static let slide: CGFloat = 24

  private let window = ChipWindow()
  private let hosting: ChipHostingView
  private let edge: () -> PanelEdge
  private let shownPanelFrame: @MainActor () -> CGRect?
  private let pointer: @MainActor () -> CGPoint
  private let visibleFrame: @MainActor (CGPoint) -> CGRect
  private let orderFront: @MainActor (NSWindow) -> Void
  private let visibility: AppVisibility
  private var transition = 0
  private var hideTask: Task<Void, Never>?
  private var content: AnyView?
  private(set) var isShown = false
  private(set) var shownFrame: CGRect?
  var windowFrame: CGRect { window.frame }
  var windowAlpha: CGFloat { window.alphaValue }

  init(
    edge: @escaping () -> PanelEdge,
    shownPanelFrame: @escaping @MainActor () -> CGRect? = { nil },
    pointer: @escaping @MainActor () -> CGPoint = { NSEvent.mouseLocation },
    visibleFrame: @escaping @MainActor (CGPoint) -> CGRect = EdgeChipPanel.visibleFrame(
      containing:),
    orderFront: @escaping @MainActor (NSWindow) -> Void = { $0.orderFrontRegardless() },
    visibility: AppVisibility = .live
  ) {
    self.edge = edge
    self.shownPanelFrame = shownPanelFrame
    self.pointer = pointer
    self.visibleFrame = visibleFrame
    self.orderFront = orderFront
    self.visibility = visibility
    hosting = ChipHostingView(rootView: AnyView(EmptyView()))
    hosting.sizingOptions = []
    window.contentView = hosting
  }

  static func chipFrame(size: CGSize, visible: CGRect, edge: PanelEdge) -> CGRect {
    frames(size: size, visible: visible, edge: edge).chip
  }

  static func frames(size: CGSize, visible: CGRect, edge: PanelEdge) -> (
    chip: CGRect, window: CGRect
  ) {
    let panel = PanelController.frame(in: visible, edge: edge)
    let atEdge: CGFloat =
      switch edge {
      case .right: visible.maxX - edgeInset - size.width
      case .left: visible.minX + edgeInset
      }
    var chip = CGRect(
      x: atEdge, y: visible.minY + bottomInset, width: size.width, height: size.height)
    if chip.insetBy(dx: -panelGap, dy: -panelGap).intersects(panel) {
      chip.origin.x =
        switch edge {
        case .right: max(panel.minX - panelGap - size.width, visible.minX)
        case .left: min(panel.maxX + panelGap, visible.maxX - size.width)
        }
    }
    let outer = chip.insetBy(dx: -shadowMargin, dy: -shadowMargin).intersection(visible)
    var (minX, maxX, minY, maxY) = (outer.minX, outer.maxX, outer.minY, outer.maxY)
    if chip.maxX <= panel.minX {
      maxX = min(maxX, panel.minX)
    } else if chip.minX >= panel.maxX {
      minX = max(minX, panel.maxX)
    } else if chip.maxY <= panel.minY {
      maxY = min(maxY, panel.minY)
    } else if chip.minY >= panel.maxY {
      minY = max(minY, panel.maxY)
    }
    return (chip, CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
  }

  static func padding(around chip: CGRect, in window: CGRect) -> EdgeInsets {
    EdgeInsets(
      top: window.maxY - chip.maxY, leading: chip.minX - window.minX,
      bottom: chip.minY - window.minY, trailing: window.maxX - chip.maxX)
  }

  func show(
    _ content: some View, hideAfter lifetime: TimeInterval? = nil, onClick: (() -> Void)? = nil
  ) {
    hideTask?.cancel()
    visibility.revealBeforeOrderingFront()
    let placed = placement()
    self.content = AnyView(content)
    hosting.rootView = AnyView(
      content.padding(Self.padding(around: placed.chip, in: placed.window)))
    hosting.onClick = onClick
    window.ignoresMouseEvents = onClick == nil
    shownFrame = placed.chip
    let target = placed.window
    transition += 1
    if isShown {
      window.setFrameAtOnce(target, display: true)
    } else {
      isShown = true
      let start = reduceMotion ? target : target.offsetBy(dx: slideOffset, dy: 0)
      window.setFrameAtOnce(start, display: false)
      window.alphaValue = 0
      orderFront(window)
      animate(frame: target, alpha: 1, completion: nil)
    }
    if let lifetime {
      hideTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(lifetime))
        guard !Task.isCancelled else { return }
        self?.hide()
      }
    }
  }

  func reposition() {
    guard isShown, let content else { return }
    let placed = placement()
    hosting.rootView = AnyView(
      content.padding(Self.padding(around: placed.chip, in: placed.window)))
    shownFrame = placed.chip
    transition += 1
    if reduceMotion {
      window.setFrameAtOnce(placed.window, display: true)
    } else {
      animate(frame: placed.window, alpha: 1, completion: nil)
    }
  }

  func hide() {
    hideTask?.cancel()
    guard isShown else { return }
    isShown = false
    shownFrame = nil
    transition += 1
    let current = transition
    let target = reduceMotion ? window.frame : window.frame.offsetBy(dx: slideOffset, dy: 0)
    animate(frame: target, alpha: 0) { [weak self] in
      guard let self, self.transition == current else { return }
      self.window.orderOut(nil)
    }
  }

  private var slideOffset: CGFloat {
    edge() == .right ? Self.slide : -Self.slide
  }

  private func placement() -> (chip: CGRect, window: CGRect) {
    Self.frames(
      size: ChipSurface<EmptyView>.size,
      visible: visibleFrame(Self.screenPoint(panel: shownPanelFrame(), pointer: pointer())),
      edge: edge())
  }

  static func screenPoint(panel: CGRect?, pointer: CGPoint) -> CGPoint {
    panel.map { CGPoint(x: $0.midX, y: $0.midY) } ?? pointer
  }

  static func visibleFrame(containing point: CGPoint) -> CGRect {
    let screen =
      NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
      ?? NSScreen.main ?? NSScreen.screens[0]
    return screen.visibleFrame
  }

  private var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  private func animate(frame: CGRect, alpha: CGFloat, completion: (@MainActor () -> Void)?) {
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = Self.duration
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        window.animator().setFrame(frame, display: true)
        window.animator().alphaValue = alpha
      },
      completionHandler: {
        MainActor.assumeIsolated { completion?() }
      })
  }
}

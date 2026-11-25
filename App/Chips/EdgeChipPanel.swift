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
  private let plannedPanelFrame: @MainActor (CGRect) -> CGRect?
  private let pointer: @MainActor () -> CGPoint
  private let visibleFrame: @MainActor (CGPoint) -> CGRect
  private let screens: @MainActor () -> [ScreenFrames]
  private let reducesMotion: @MainActor () -> Bool
  private let orderFront: @MainActor (NSWindow) -> Void
  private let visibility: AppVisibility
  private var transition = 0
  private var hideTask: Task<Void, Never>?
  private var content: AnyView?
  private(set) var isShown = false
  private(set) var shownFrame: CGRect?
  private var restingFrame: CGRect?
  var windowFrame: CGRect { window.frame }
  var windowAlpha: CGFloat { window.alphaValue }

  init(
    edge: @escaping () -> PanelEdge,
    shownPanelFrame: @escaping @MainActor () -> CGRect? = { nil },
    plannedPanelFrame: @escaping @MainActor (CGRect) -> CGRect? = { _ in nil },
    pointer: @escaping @MainActor () -> CGPoint = { NSEvent.mouseLocation },
    visibleFrame: @escaping @MainActor (CGPoint) -> CGRect = EdgeChipPanel.visibleFrame(
      containing:),
    screens: @escaping @MainActor () -> [ScreenFrames] = ScreenList.live,
    orderFront: @escaping @MainActor (NSWindow) -> Void = { $0.orderFrontRegardless() },
    visibility: AppVisibility = .live,
    reducesMotion: @escaping @MainActor () -> Bool = {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
  ) {
    self.edge = edge
    self.shownPanelFrame = shownPanelFrame
    self.plannedPanelFrame = plannedPanelFrame
    self.pointer = pointer
    self.visibleFrame = visibleFrame
    self.screens = screens
    self.reducesMotion = reducesMotion
    self.orderFront = orderFront
    self.visibility = visibility
    hosting = ChipHostingView(rootView: AnyView(EmptyView()))
    hosting.sizingOptions = []
    window.contentView = hosting
  }

  static func chipFrame(size: CGSize, visible: CGRect, edge: PanelEdge) -> CGRect {
    frames(size: size, visible: visible, edge: edge).chip
  }

  static func frames(size: CGSize, visible: CGRect, edge: PanelEdge, panel: CGRect? = nil) -> (
    chip: CGRect, window: CGRect
  ) {
    let panel = panel ?? PanelController.frame(in: visible, edge: edge)
    let atEdge: CGFloat =
      switch edge {
      case .right: visible.maxX - edgeInset - size.width
      case .left: visible.minX + edgeInset
      }
    let beside: CGFloat =
      switch edge {
      case .right: panel.minX - panelGap - size.width
      case .left: panel.maxX + panelGap
      }
    let squeezed = min(max(beside, visible.minX), visible.maxX - size.width)
    let spots = [atEdge, beside, squeezed].map {
      CGRect(x: $0, y: visible.minY + bottomInset, width: size.width, height: size.height)
    }
    let chip =
      spots.first {
        visible.contains($0) && !$0.insetBy(dx: -panelGap, dy: -panelGap).intersects(panel)
      } ?? spots[2]
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
    restingFrame = target
    transition += 1
    if isShown {
      window.setFrameAtOnce(target, display: true)
    } else {
      isShown = true
      let start = slid(target) ?? target
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
    let from = restingFrame ?? window.frame
    restingFrame = placed.window
    transition += 1
    if reduceMotion {
      window.setFrameAtOnce(placed.window, display: true)
    } else if ScreenList.movesOntoAnotherScreen(from: from, to: placed.window, among: screens()) {
      window.alphaValue = 0
      window.setFrameAtOnce(placed.window, display: true)
      animate(frame: placed.window, alpha: 1, completion: nil)
    } else {
      animate(frame: placed.window, alpha: 1, completion: nil)
    }
  }

  func hide() {
    hideTask?.cancel()
    guard isShown else { return }
    isShown = false
    shownFrame = nil
    let resting = restingFrame ?? window.frame
    restingFrame = nil
    transition += 1
    let current = transition
    let slides = slid(resting) != nil
    let target = slides ? window.frame.offsetBy(dx: slideOffset, dy: 0) : window.frame
    animate(frame: target, alpha: 0) { [weak self] in
      guard let self, self.transition == current else { return }
      self.window.orderOut(nil)
    }
  }

  private var slideOffset: CGFloat {
    edge() == .right ? Self.slide : -Self.slide
  }

  private func slid(_ frame: CGRect) -> CGRect? {
    reduceMotion ? nil : Self.slid(frame, toward: edge(), among: screens())
  }

  private func placement() -> (chip: CGRect, window: CGRect) {
    let shown = shownPanelFrame()
    let visible = visibleFrame(Self.screenPoint(panel: shown, pointer: pointer()))
    return Self.frames(
      size: ChipSurface<EmptyView>.size, visible: visible, edge: edge(),
      panel: shown ?? plannedPanelFrame(visible))
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

  static func slid(_ frame: CGRect, toward edge: PanelEdge, among screens: [ScreenFrames])
    -> CGRect?
  {
    let slid = frame.offsetBy(dx: edge == .right ? slide : -slide, dy: 0)
    return ScreenList.movesOntoAnotherScreen(from: frame, to: slid, among: screens) ? nil : slid
  }

  private var reduceMotion: Bool { reducesMotion() }

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

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
  private let openPanelFrame: () -> CGRect?
  private var transition = 0
  private var hideTask: Task<Void, Never>?
  private(set) var isShown = false

  init(edge: @escaping () -> PanelEdge, openPanelFrame: @escaping () -> CGRect?) {
    self.edge = edge
    self.openPanelFrame = openPanelFrame
    hosting = ChipHostingView(rootView: AnyView(EmptyView()))
    hosting.sizingOptions = []
    window.contentView = hosting
  }

  static func chipFrame(
    size: CGSize, visible: CGRect, edge: PanelEdge, openPanel: CGRect?
  ) -> CGRect {
    let y = visible.minY + bottomInset
    let x: CGFloat
    switch (edge, openPanel) {
    case (.right, nil): x = visible.maxX - edgeInset - size.width
    case (.left, nil): x = visible.minX + edgeInset
    case (.right, let panel?): x = panel.minX - panelGap - size.width
    case (.left, let panel?): x = panel.maxX + panelGap
    }
    return CGRect(x: x, y: y, width: size.width, height: size.height)
  }

  func show(
    _ content: some View, hideAfter lifetime: TimeInterval? = nil, onClick: (() -> Void)? = nil
  ) {
    hideTask?.cancel()
    hosting.rootView = AnyView(content.padding(Self.shadowMargin))
    hosting.onClick = onClick
    window.ignoresMouseEvents = onClick == nil
    let target = windowFrame()
    transition += 1
    if isShown {
      window.setFrame(target, display: true)
    } else {
      isShown = true
      let start = reduceMotion ? target : target.offsetBy(dx: slideOffset, dy: 0)
      window.setFrame(start, display: false)
      window.alphaValue = 0
      window.orderFrontRegardless()
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
    guard isShown else { return }
    animate(frame: windowFrame(), alpha: 1, completion: nil)
  }

  func hide() {
    hideTask?.cancel()
    guard isShown else { return }
    isShown = false
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

  private func windowFrame() -> CGRect {
    let openPanel = openPanelFrame()
    let visible = Self.visibleFrame(containing: openPanel)
    let size = ChipSurface<EmptyView>.size
    let chip = Self.chipFrame(size: size, visible: visible, edge: edge(), openPanel: openPanel)
    return chip.insetBy(dx: -Self.shadowMargin, dy: -Self.shadowMargin)
  }

  private static func visibleFrame(containing panel: CGRect?) -> CGRect {
    let point = panel.map { CGPoint(x: $0.midX, y: $0.midY) } ?? NSEvent.mouseLocation
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

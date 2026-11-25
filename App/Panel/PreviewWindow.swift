import AppKit
import SwiftUI
import ThoughtsCore

final class PreviewPanel: NSPanel {
  init(content: NSView) {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: true)
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    hidesOnDeactivate = false
    isMovable = false
    isReleasedWhenClosed = false
    animationBehavior = .none
    becomesKeyOnlyIfNeeded = true
    contentView = content
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class PreviewWindowController {
  static let gap: CGFloat = 12

  private let panel: PreviewPanel
  private let list: ListModel
  private let hosting: NSHostingView<PreviewHost>
  private let anchor: () -> (frame: CGRect, edge: PanelEdge)?
  private let screens: @MainActor () -> [(frame: CGRect, visible: CGRect)]
  private var transition = 0

  init(
    list: ListModel, anchor: @escaping () -> (frame: CGRect, edge: PanelEdge)?,
    screens: @escaping @MainActor () -> [(frame: CGRect, visible: CGRect)] = {
      NSScreen.screens.map { ($0.frame, $0.visibleFrame) }
    }
  ) {
    let hosting = NSHostingView(rootView: PreviewHost(list: list))
    hosting.sizingOptions = []
    self.list = list
    self.hosting = hosting
    self.panel = PreviewPanel(content: hosting)
    self.anchor = anchor
    self.screens = screens
  }

  var frame: CGRect { panel.frame }
  var alpha: CGFloat { panel.alphaValue }
  var isVisible: Bool { panel.isVisible }
  private(set) var loadedImage: URL?

  static func visibleFrame(
    for panel: CGRect, among screens: [(frame: CGRect, visible: CGRect)]
  ) -> CGRect? {
    screens.min { rank($0.frame, for: panel) < rank($1.frame, for: panel) }?.visible
  }

  private static func rank(_ screen: CGRect, for panel: CGRect) -> (CGFloat, CGFloat) {
    let shared = screen.intersection(panel)
    let center = CGPoint(x: panel.midX, y: panel.midY)
    let dx = max(screen.minX - center.x, 0, center.x - screen.maxX)
    let dy = max(screen.minY - center.y, 0, center.y - screen.maxY)
    return (-(shared.width * shared.height), hypot(dx, dy))
  }

  static func placement(
    beside panel: CGRect, edge: PanelEdge, in visible: CGRect,
    height: (PreviewCardLayout) -> CGFloat
  ) -> (frame: CGRect, layout: PreviewCardLayout) {
    let leftEnd = min(panel.minX - gap, visible.maxX)
    let rightStart = max(panel.maxX + gap, visible.minX)
    let leftRoom = leftEnd - visible.minX
    let rightRoom = visible.maxX - rightStart
    let inward = edge == .right ? leftRoom : rightRoom
    let outward = edge == .right ? rightRoom : leftRoom
    let staysInward = inward >= PreviewCardLayout.fullWidth || inward >= outward
    let onLeft = staysInward == (edge == .right)
    let room = staysInward ? inward : outward
    var layout: PreviewCardLayout
    let x: CGFloat
    if room >= PreviewCardLayout.minimumWidth {
      layout = PreviewCardLayout(width: min(PreviewCardLayout.fullWidth, room).rounded(.down))
      x = onLeft ? leftEnd - layout.width : rightStart
    } else {
      layout = PreviewCardLayout(
        width: min(PreviewCardLayout.minimumWidth, visible.width).rounded(.down))
      x = panel.minX + gap
    }
    let tallest = min(panel.height, visible.height)
    var fitted = height(layout)
    if fitted > tallest {
      layout.mediaHeight = max(layout.mediaHeight - (fitted - tallest).rounded(.up), 0)
      fitted = height(layout)
    }
    let size = CGSize(width: layout.width, height: min(fitted, visible.height))
    let origin = CGPoint(
      x: min(max(x, visible.minX), visible.maxX - size.width),
      y: min(max(panel.midY - size.height / 2, visible.minY), visible.maxY - size.height))
    return (CGRect(origin: origin, size: size), layout)
  }

  static func height(of thought: Thought, layout: PreviewCardLayout) -> CGFloat {
    NSHostingView(rootView: PreviewView(thought: thought, image: nil, layout: layout))
      .fittingSize.height
  }

  func update(showing thought: Thought?) {
    guard let thought, let anchor = anchor(),
      let visible = Self.visibleFrame(for: anchor.frame, among: screens())
    else {
      hide()
      return
    }
    let placed = Self.placement(beside: anchor.frame, edge: anchor.edge, in: visible) {
      Self.height(of: thought, layout: $0)
    }
    hosting.rootView = PreviewHost(list: list, layout: placed.layout, size: placed.frame.size) {
      [weak self] in self?.loadedImage = $0
    }
    transition += 1
    let wasHidden = !panel.isVisible
    panel.setFrame(placed.frame, display: true)
    if wasHidden { panel.alphaValue = 0 }
    panel.orderFront(nil)
    if panel.alphaValue < 1 { fade(to: 1, completion: nil) }
    followContent()
  }

  private func followContent() {
    let current = transition
    withObservationTracking {
      _ = list.previewThought
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self, self.transition == current, self.list.isPreviewing else { return }
        self.list.settlePreview()
        if self.list.isPreviewing { self.update(showing: self.list.previewThought) }
      }
    }
  }

  func hide() {
    guard panel.isVisible else { return }
    transition += 1
    let current = transition
    fade(to: 0) { [weak self] in
      guard let self, self.transition == current else { return }
      self.panel.orderOut(nil)
    }
  }

  private func fade(to alpha: CGFloat, completion: (@MainActor () -> Void)?) {
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = PanelController.duration
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        panel.animator().alphaValue = alpha
      },
      completionHandler: {
        MainActor.assumeIsolated { completion?() }
      })
  }
}

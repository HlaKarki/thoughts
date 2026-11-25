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
  private let screens: @MainActor () -> [ScreenFrames]
  private let visibility: AppVisibility
  private let reducesMotion: @MainActor () -> Bool
  private var transition = 0

  init(
    list: ListModel, anchor: @escaping () -> (frame: CGRect, edge: PanelEdge)?,
    screens: @escaping @MainActor () -> [ScreenFrames] = ScreenList.live,
    visibility: AppVisibility = .live,
    reducesMotion: @escaping @MainActor () -> Bool = {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
  ) {
    let hosting = NSHostingView(rootView: PreviewHost(list: list))
    hosting.sizingOptions = []
    self.list = list
    self.hosting = hosting
    self.panel = PreviewPanel(content: hosting)
    self.anchor = anchor
    self.screens = screens
    self.visibility = visibility
    self.reducesMotion = reducesMotion
  }

  var frame: CGRect { panel.frame }
  var alpha: CGFloat { panel.alphaValue }
  var isVisible: Bool { panel.isVisible }
  private(set) var loadedImage: URL?

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

  func reposition() {
    guard panel.isVisible, list.isPreviewing else { return }
    update(showing: list.previewThought, animated: true)
  }

  func update(showing thought: Thought?, animated: Bool = false) {
    guard let thought, let anchor = anchor(),
      let visible = ScreenList.visibleFrame(for: anchor.frame, among: screens())
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
    let crosses =
      !wasHidden
      && ScreenList.movesOntoAnotherScreen(from: panel.frame, to: placed.frame, among: screens())
    if animated, !wasHidden, !crosses, !reduceMotion {
      slide(to: placed.frame)
    } else {
      panel.setFrameAtOnce(placed.frame, display: true)
    }
    if wasHidden || crosses { panel.alphaValue = 0 }
    visibility.revealBeforeOrderingFront()
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

  private var reduceMotion: Bool { reducesMotion() }

  private func slide(to frame: CGRect) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = PanelController.duration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().setFrame(frame, display: true)
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

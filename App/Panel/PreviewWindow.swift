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
    ignoresMouseEvents = true
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
  private var transition = 0

  init(list: ListModel, anchor: @escaping () -> (frame: CGRect, edge: PanelEdge)?) {
    let hosting = NSHostingView(rootView: PreviewHost(list: list))
    hosting.sizingOptions = []
    self.list = list
    self.hosting = hosting
    self.panel = PreviewPanel(content: hosting)
    self.anchor = anchor
  }

  static func frame(beside panel: CGRect, edge: PanelEdge, size: CGSize, in visible: CGRect)
    -> CGRect
  {
    let height = min(size.height, panel.height)
    let room =
      switch edge {
      case .right: panel.minX - gap - visible.minX
      case .left: visible.maxX - (panel.maxX + gap)
      }
    let width = min(size.width, max(room, 0))
    let x =
      switch edge {
      case .right: panel.minX - gap - width
      case .left: panel.maxX + gap
      }
    return CGRect(x: x, y: panel.midY - height / 2, width: width, height: height)
  }

  func update(showing thought: Thought?) {
    guard thought != nil, let anchor = anchor() else {
      hide()
      return
    }
    hosting.rootView = PreviewHost(list: list)
    hosting.frame = CGRect(
      origin: .zero, size: CGSize(width: PreviewView.width, height: hosting.frame.height))
    hosting.layoutSubtreeIfNeeded()
    let size = hosting.fittingSize
    let screen = NSScreen.screens.first { $0.frame.intersects(anchor.frame) }
    let frame = Self.frame(
      beside: anchor.frame, edge: anchor.edge, size: size,
      in: screen?.visibleFrame ?? anchor.frame)
    transition += 1
    let wasHidden = !panel.isVisible
    panel.setFrame(frame, display: true)
    if wasHidden { panel.alphaValue = 0 }
    panel.orderFront(nil)
    if panel.alphaValue < 1 { fade(to: 1, completion: nil) }
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

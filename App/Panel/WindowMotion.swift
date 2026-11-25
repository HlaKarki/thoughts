import AppKit

extension NSWindow {
  func setFrameAtOnce(_ frame: CGRect, display: Bool = true) {
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0
        animator().setFrame(frame, display: display)
      }, completionHandler: nil)
    setFrame(frame, display: display)
  }
}

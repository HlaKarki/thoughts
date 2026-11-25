import AppKit
import Testing

@testable import Thoughts

@MainActor
struct WindowMotionTests {
  @Test func aMoveAtOnceWinsOverASlideStillRunning() async throws {
    let window = NSPanel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: true)
    let union = NSScreen.screens.map(\.frame).reduce(CGRect.null) { $0.union($1) }
    let start = CGRect(x: union.maxX + 4000, y: union.minY, width: 360, height: 640)
    let slide = start.offsetBy(dx: 400, dy: 0)
    let jump = start.offsetBy(dx: 1000, dy: 0)
    window.setFrame(start, display: false)
    window.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0.3
        window.animator().setFrame(slide, display: true)
      }, completionHandler: nil)
    try await Task.sleep(for: .milliseconds(40))
    window.setFrameAtOnce(jump)
    #expect(window.frame == jump)
    try await Task.sleep(for: .milliseconds(500))
    #expect(window.frame == jump, "the slide took the window to \(window.frame)")
    window.orderOut(nil)
  }
}

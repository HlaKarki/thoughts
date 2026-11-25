import AppKit

typealias ScreenFrames = (frame: CGRect, visible: CGRect)

enum ScreenList {
  @MainActor static func live() -> [ScreenFrames] {
    NSScreen.screens.map { ($0.frame, $0.visibleFrame) }
  }

  static func screen(for window: CGRect, among screens: [ScreenFrames]) -> ScreenFrames? {
    screens.min { rank($0.frame, for: window) < rank($1.frame, for: window) }
  }

  static func visibleFrame(for window: CGRect, among screens: [ScreenFrames]) -> CGRect? {
    screen(for: window, among: screens)?.visible
  }

  static func movesOntoAnotherScreen(
    from start: CGRect, to end: CGRect, among screens: [ScreenFrames]
  ) -> Bool {
    let home = screen(for: start, among: screens)?.frame
    return screens.contains { $0.frame != home && $0.frame.intersects(end) }
  }

  private static func rank(_ screen: CGRect, for window: CGRect) -> (CGFloat, CGFloat) {
    let shared = screen.intersection(window)
    let center = CGPoint(x: window.midX, y: window.midY)
    let dx = max(screen.minX - center.x, 0, center.x - screen.maxX)
    let dy = max(screen.minY - center.y, 0, center.y - screen.maxY)
    return (-(shared.width * shared.height), hypot(dx, dy))
  }
}

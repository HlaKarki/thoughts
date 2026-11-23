import AppKit

enum MenuBarGlyph {
  static let glyphSize = CGSize(width: 18, height: 18)
  static let dotDiameter: CGFloat = 6
  static let dotGap: CGFloat = 2

  static let bar = CGRect(x: 0, y: 2, width: 13, height: 4)
  static let caret = CGRect(x: 15, y: 2, width: 3, height: 14)

  static let canvas = CGSize(
    width: glyphSize.width + dotGap + dotDiameter, height: glyphSize.height)
  static let buttonLength: CGFloat = 28

  static var dotRect: CGRect {
    CGRect(
      x: glyphSize.width + dotGap, y: caret.maxY - dotDiameter, width: dotDiameter,
      height: dotDiameter)
  }

  static func draw() {
    NSBezierPath(roundedRect: bar, xRadius: bar.height / 2, yRadius: bar.height / 2).fill()
    NSBezierPath(roundedRect: caret, xRadius: caret.width / 2, yRadius: caret.width / 2).fill()
  }

  static func image() -> NSImage {
    let image = NSImage(size: canvas, flipped: false) { _ in
      NSColor.black.setFill()
      draw()
      return true
    }
    image.isTemplate = true
    return image
  }

  static func dotFrame(in bounds: CGRect, flipped: Bool) -> CGRect {
    let originX = bounds.midX - canvas.width / 2
    let y =
      flipped
      ? bounds.midY - canvas.height / 2 + (canvas.height - dotRect.maxY)
      : bounds.midY - canvas.height / 2 + dotRect.minY
    return CGRect(x: originX + dotRect.minX, y: y, width: dotDiameter, height: dotDiameter)
  }

  static func label(updateWaiting: Bool) -> String {
    updateWaiting
      ? String(localized: "Thoughts, update available") : String(localized: "Thoughts")
  }

  @MainActor
  static func install(dot: NSView, in container: NSView) {
    dot.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
    container.addSubview(dot)
    place(dot: dot, in: container)
  }

  @MainActor
  static func place(dot: NSView, in container: NSView) {
    dot.frame = dotFrame(in: container.bounds, flipped: container.isFlipped)
  }
}

final class UpdateDotView: NSView {
  override var isFlipped: Bool { true }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.controlAccentColor.setFill()
    NSBezierPath(ovalIn: bounds).fill()
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

import AppKit

enum MenuBarGlyph {
  static let size = CGSize(width: 18, height: 18)
  static let buttonLength: CGFloat = 24
  static let dotDiameter: CGFloat = 6

  static let bar = CGRect(x: 0, y: 2, width: 13, height: 4)
  static let caret = CGRect(x: 15, y: 2, width: 3, height: 14)
  static let dotRect = CGRect(
    x: bar.minX, y: caret.maxY - dotDiameter, width: dotDiameter, height: dotDiameter)

  static let blue = NSGradient(
    starting: NSColor(srgbRed: 0x52 / 255, green: 0xA8 / 255, blue: 1, alpha: 1),
    ending: NSColor(srgbRed: 0, green: 0x66 / 255, blue: 0xEE / 255, alpha: 1))

  static func fillBlue(_ path: NSBezierPath) {
    blue?.draw(in: path, angle: 270)
  }

  static func draw(includingCaret: Bool) {
    NSBezierPath(roundedRect: bar, xRadius: bar.height / 2, yRadius: bar.height / 2).fill()
    guard includingCaret else { return }
    NSBezierPath(roundedRect: caret, xRadius: caret.width / 2, yRadius: caret.width / 2).fill()
  }

  static func image(updateWaiting: Bool) -> NSImage {
    let image = NSImage(size: size, flipped: false) { _ in
      NSColor.black.setFill()
      draw(includingCaret: !updateWaiting)
      return true
    }
    image.isTemplate = true
    return image
  }

  static func frame(of rect: CGRect, in bounds: CGRect, flipped: Bool) -> CGRect {
    let originX = bounds.midX - size.width / 2
    let y =
      flipped
      ? bounds.midY - size.height / 2 + (size.height - rect.maxY)
      : bounds.midY - size.height / 2 + rect.minY
    return CGRect(x: originX + rect.minX, y: y, width: rect.width, height: rect.height)
  }

  static func label(updateWaiting: Bool) -> String {
    updateWaiting
      ? String(localized: "Thoughts, update available") : String(localized: "Thoughts")
  }

  @MainActor
  static func install(caret: NSView, dot: NSView, in container: NSView) {
    for overlay in [caret, dot] {
      overlay.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
      container.addSubview(overlay)
    }
    place(caret: caret, dot: dot, in: container)
  }

  @MainActor
  static func place(caret: NSView, dot: NSView, in container: NSView) {
    caret.frame = frame(of: Self.caret, in: container.bounds, flipped: container.isFlipped)
    dot.frame = frame(of: dotRect, in: container.bounds, flipped: container.isFlipped)
  }
}

final class UpdateCaretView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    let path = NSBezierPath(
      roundedRect: bounds, xRadius: bounds.width / 2, yRadius: bounds.width / 2)
    MenuBarGlyph.fillBlue(path)
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class UpdateDotView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    MenuBarGlyph.fillBlue(NSBezierPath(ovalIn: bounds))
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

import AppKit

enum MenuBarGlyph {
  static let size = CGSize(width: 18, height: 18)
  static let buttonLength: CGFloat = 24
  static let dotDiameter: CGFloat = 6
  static let dotOffset = CGPoint(x: 9, y: 8)
  static let cutoutRadius: CGFloat = 4

  private static let bar = CGRect(x: 0, y: 2, width: 13, height: 4)
  private static let caret = CGRect(x: 15, y: 2, width: 3, height: 14)

  static func draw(updateWaiting: Bool) {
    NSBezierPath(roundedRect: bar, xRadius: bar.height / 2, yRadius: bar.height / 2).fill()
    NSBezierPath(roundedRect: caret, xRadius: caret.width / 2, yRadius: caret.width / 2).fill()
    guard updateWaiting else { return }
    NSGraphicsContext.current?.compositingOperation = .destinationOut
    let center = CGPoint(x: size.width / 2 + dotOffset.x, y: size.height / 2 + dotOffset.y)
    NSBezierPath(
      ovalIn: CGRect(
        x: center.x - cutoutRadius, y: center.y - cutoutRadius, width: cutoutRadius * 2,
        height: cutoutRadius * 2)
    ).fill()
  }

  static func image(updateWaiting: Bool) -> NSImage {
    let image = NSImage(size: size, flipped: false) { _ in
      NSColor.black.setFill()
      draw(updateWaiting: updateWaiting)
      return true
    }
    image.isTemplate = true
    return image
  }

  static func dotFrame(in bounds: CGRect, flipped: Bool) -> CGRect {
    let centerY = flipped ? bounds.midY - dotOffset.y : bounds.midY + dotOffset.y
    return CGRect(
      x: bounds.midX + dotOffset.x - dotDiameter / 2, y: centerY - dotDiameter / 2,
      width: dotDiameter, height: dotDiameter)
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

import AppKit

struct PanelPosition: Codable, Equatable {
  enum Place: Codable, Equatable {
    case start
    case end
    case fraction(CGFloat)
  }

  var x: Place
  var y: Place

  init(x: Place, y: Place) {
    self.x = x
    self.y = y
  }

  init(frame: CGRect, in visible: CGRect) {
    x = Self.place(frame.minX, length: frame.width, from: visible.minX, to: visible.maxX)
    y = Self.place(frame.minY, length: frame.height, from: visible.minY, to: visible.maxY)
  }

  func frame(size: CGSize, in visible: CGRect) -> CGRect {
    CGRect(
      x: Self.offset(x, length: size.width, from: visible.minX, to: visible.maxX),
      y: Self.offset(y, length: size.height, from: visible.minY, to: visible.maxY),
      width: size.width, height: size.height)
  }

  var side: PanelEdge? {
    switch x {
    case .start: .left
    case .end: .right
    case .fraction(let share): share < 0.5 ? .left : share > 0.5 ? .right : nil
    }
  }

  func moved(to edge: PanelEdge) -> PanelPosition {
    side == edge ? self : PanelPosition(x: edge == .left ? .start : .end, y: y)
  }

  private static let tolerance: CGFloat = 0.5

  private static func place(
    _ low: CGFloat, length: CGFloat, from minimum: CGFloat, to maximum: CGFloat
  ) -> Place {
    let inset = PanelController.edgeInset
    let atStart = abs(low - (minimum + inset)) < tolerance
    let atEnd = abs(low + length - (maximum - inset)) < tolerance
    if atStart != atEnd { return atStart ? .start : .end }
    let travel = maximum - minimum - length
    guard travel > 0 else { return .fraction(0.5) }
    return .fraction(min(max((low - minimum) / travel, 0), 1))
  }

  private static func offset(
    _ place: Place, length: CGFloat, from minimum: CGFloat, to maximum: CGFloat
  ) -> CGFloat {
    let travel = max(maximum - minimum - length, 0)
    let inset = min(PanelController.edgeInset, travel)
    switch place {
    case .start: return minimum + inset
    case .end: return minimum + travel - inset
    case .fraction(let share): return (minimum + min(max(share, 0), 1) * travel).rounded()
    }
  }
}

extension PanelController {
  static func size(in visible: CGRect) -> CGSize {
    CGSize(width: width, height: min(maxHeight, visible.height - 2 * edgeInset))
  }

  static func frame(in visible: CGRect, edge: PanelEdge) -> CGRect {
    let size = size(in: visible)
    let x =
      switch edge {
      case .left: visible.minX + edgeInset
      case .right: visible.maxX - edgeInset - size.width
      }
    return CGRect(x: x, y: visible.midY - size.height / 2, width: size.width, height: size.height)
  }

  static func frame(in visible: CGRect, edge: PanelEdge, position: PanelPosition?) -> CGRect {
    guard let position else { return frame(in: visible, edge: edge) }
    return position.frame(size: size(in: visible), in: visible)
  }

  static func offscreenFrame(from frame: CGRect, edge: PanelEdge) -> CGRect {
    let travel = width + edgeInset
    return frame.offsetBy(dx: edge == .right ? travel : -travel, dy: 0)
  }

  static func dropped(_ frame: CGRect, in visible: CGRect) -> CGRect {
    let size = size(in: visible)
    return CGRect(
      x: snapped(frame.minX, length: size.width, from: visible.minX, to: visible.maxX),
      y: snapped(
        frame.maxY - size.height, length: size.height, from: visible.minY, to: visible.maxY),
      width: size.width, height: size.height)
  }

  static func side(of frame: CGRect, in visible: CGRect) -> PanelEdge? {
    if frame.midX < visible.midX { return .left }
    if frame.midX > visible.midX { return .right }
    return nil
  }

  static func edge(of frame: CGRect, in visible: CGRect, current: PanelEdge) -> PanelEdge {
    side(of: frame, in: visible) ?? current
  }

  static func slideEdge(of frame: CGRect, in visible: CGRect, preferring edge: PanelEdge)
    -> PanelEdge?
  {
    let left = abs(frame.minX - (visible.minX + edgeInset)) < 0.5
    let right = abs(frame.maxX - (visible.maxX - edgeInset)) < 0.5
    switch (left, right) {
    case (true, true): return edge
    case (true, false): return .left
    case (false, true): return .right
    case (false, false): return nil
    }
  }

  static func moved(_ frame: CGRect, to edge: PanelEdge, in visible: CGRect) -> CGRect {
    guard side(of: frame, in: visible) != edge else { return frame }
    let size = size(in: visible)
    let x =
      switch edge {
      case .left: visible.minX + edgeInset
      case .right: visible.maxX - edgeInset - size.width
      }
    let y = min(max(frame.maxY - size.height, visible.minY), visible.maxY - size.height)
    return CGRect(x: x, y: y, width: size.width, height: size.height)
  }

  private static func snapped(
    _ low: CGFloat, length: CGFloat, from minimum: CGFloat, to maximum: CGFloat
  ) -> CGFloat {
    let toStart = low - minimum
    let toEnd = maximum - (low + length)
    let nearStart = toStart <= snapDistance
    let nearEnd = toEnd <= snapDistance
    if nearStart, !nearEnd || toStart <= toEnd { return minimum + edgeInset }
    if nearEnd { return maximum - edgeInset - length }
    return min(max(low.rounded(), minimum), maximum - length)
  }
}

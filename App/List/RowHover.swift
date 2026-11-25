import CoreGraphics
import Observation

struct PointerMap<ID: Hashable> {
  private var frames: [ID: CGRect] = [:]
  private let slack: CGFloat

  init(slack: CGFloat = 0) {
    self.slack = slack
  }

  mutating func place(_ id: ID, at frame: CGRect?) {
    frames[id] = frame
  }

  func item(at point: CGPoint?) -> ID? {
    guard let point else { return nil }
    return frames.first { $0.value.insetBy(dx: 0, dy: -slack).contains(point) }?.key
  }
}

@MainActor
@Observable
final class RowHover {
  static let space = "thoughts.list"

  private(set) var row: String?
  @ObservationIgnored private var pointer: CGPoint?
  @ObservationIgnored private var cover: CGRect?
  @ObservationIgnored private var rows = PointerMap<String>(slack: ThoughtListView.rowSpacing / 2)

  func pointerMoved(to point: CGPoint?) {
    pointer = point
    refresh()
  }

  func place(_ name: String, at frame: CGRect?) {
    rows.place(name, at: frame)
    refresh()
  }

  func cover(_ frame: CGRect?) {
    cover = frame
    refresh()
  }

  func clear() {
    pointer = nil
    refresh()
  }

  private func refresh() {
    let next = pointer.flatMap { point in
      cover?.contains(point) == true ? nil : rows.item(at: point)
    }
    if next != row { row = next }
  }
}

import AppKit

struct DragTracker {
  enum Event {
    case down
    case dragged
    case up
  }

  enum Transition {
    case began
    case ended
  }

  private var baseline: Int
  private(set) var isActive = false

  init(baseline: Int) {
    self.baseline = baseline
  }

  mutating func handle(_ event: Event, changeCount: Int) -> Transition? {
    switch event {
    case .down:
      let ended = isActive
      isActive = false
      baseline = changeCount
      return ended ? .ended : nil
    case .dragged:
      guard !isActive, changeCount != baseline else { return nil }
      isActive = true
      return .began
    case .up:
      let ended = isActive
      isActive = false
      baseline = changeCount
      return ended ? .ended : nil
    }
  }
}

@MainActor
final class DragSessionMonitor {
  typealias Install = (NSEvent.EventTypeMask, @escaping @MainActor (NSEvent.EventType) -> Void) ->
    Any?

  var onStart: () -> Void = {}
  var onEnd: () -> Void = {}

  private let pasteboard: NSPasteboard
  private let install: Install
  private let remove: (Any) -> Void
  private var tracker: DragTracker
  private var token: Any?

  init(
    pasteboard: NSPasteboard = NSPasteboard(name: .drag),
    install: @escaping Install = DragSessionMonitor.installGlobal,
    remove: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) }
  ) {
    self.pasteboard = pasteboard
    self.install = install
    self.remove = remove
    tracker = DragTracker(baseline: pasteboard.changeCount)
  }

  var isDragging: Bool { tracker.isActive }

  func start() {
    guard token == nil else { return }
    tracker = DragTracker(baseline: pasteboard.changeCount)
    token = install([.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] type in
      self?.receive(type)
    }
  }

  func stop() {
    if let token { remove(token) }
    token = nil
    if tracker.isActive { onEnd() }
    tracker = DragTracker(baseline: pasteboard.changeCount)
  }

  func receive(_ type: NSEvent.EventType) {
    let event: DragTracker.Event
    switch type {
    case .leftMouseDown: event = .down
    case .leftMouseDragged: event = .dragged
    case .leftMouseUp: event = .up
    default: return
    }
    switch tracker.handle(event, changeCount: pasteboard.changeCount) {
    case .began: onStart()
    case .ended: onEnd()
    case nil: break
    }
  }

  nonisolated static func installGlobal(
    _ mask: NSEvent.EventTypeMask, _ handler: @escaping @MainActor (NSEvent.EventType) -> Void
  ) -> Any? {
    NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
      let type = event.type
      MainActor.assumeIsolated { handler(type) }
    }
  }
}

import AppKit
import Observation
import ThoughtsCore

struct EventMonitors {
  var addGlobal: @MainActor (NSEvent.EventTypeMask, @escaping (NSEvent) -> Void) -> Any?
  var addLocal: @MainActor (NSEvent.EventTypeMask, @escaping (NSEvent) -> NSEvent?) -> Any?
  var remove: @MainActor (Any) -> Void

  static var live: EventMonitors {
    EventMonitors(
      addGlobal: { NSEvent.addGlobalMonitorForEvents(matching: $0, handler: $1) },
      addLocal: { NSEvent.addLocalMonitorForEvents(matching: $0, handler: $1) },
      remove: { NSEvent.removeMonitor($0) })
  }
}

@MainActor
final class GestureMonitor {
  private let preferences: Preferences
  private let monitors: EventMonitors
  var onGesture: @MainActor () -> Void = {}
  private var detector: DoubleTapDetector?
  private var global: Any?
  private var local: Any?
  private var running = false

  init(preferences: Preferences, monitors: EventMonitors = .live) {
    self.preferences = preferences
    self.monitors = monitors
  }

  static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<Modifier> {
    var result: Set<Modifier> = []
    if flags.contains(.shift) { result.insert(.shift) }
    if flags.contains(.option) { result.insert(.option) }
    if flags.contains(.control) { result.insert(.control) }
    if flags.contains(.command) { result.insert(.command) }
    return result
  }

  static func event(type: NSEvent.EventType, flags: NSEvent.ModifierFlags, at time: TimeInterval)
    -> ModifierEvent?
  {
    switch type {
    case .flagsChanged: .modifiers(modifiers(from: flags), at: time)
    case .keyDown: .key(at: time)
    case .leftMouseDown, .rightMouseDown, .otherMouseDown: .mouseDown(at: time)
    default: nil
    }
  }

  func start() {
    guard !running else { return }
    running = true
    apply()
    follow()
  }

  func stop() {
    running = false
    uninstall()
  }

  func reinstall() {
    guard running else { return }
    apply()
  }

  private func follow() {
    withObservationTracking {
      _ = preferences.captureMethod
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self, self.running else { return }
        self.apply()
        self.follow()
      }
    }
  }

  private func apply() {
    uninstall()
    guard let modifier = preferences.captureMethod.modifier else { return }
    detector = DoubleTapDetector(modifier: modifier)
    let mask: NSEvent.EventTypeMask = [
      .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
    ]
    global = monitors.addGlobal(mask) { [weak self] event in
      let fed = Self.event(type: event.type, flags: event.modifierFlags, at: event.timestamp)
      MainActor.assumeIsolated { self?.feed(fed) }
    }
    local = monitors.addLocal(mask) { [weak self] event in
      let fed = Self.event(type: event.type, flags: event.modifierFlags, at: event.timestamp)
      MainActor.assumeIsolated { self?.feed(fed) }
      return event
    }
  }

  private func uninstall() {
    if let global { monitors.remove(global) }
    if let local { monitors.remove(local) }
    global = nil
    local = nil
    detector = nil
  }

  private func feed(_ event: ModifierEvent?) {
    guard let event, detector?.feed(event) == true else { return }
    onGesture()
  }
}

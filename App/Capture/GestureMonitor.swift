import AppKit
import Observation
import ThoughtsCore

@MainActor
final class GestureMonitor {
  private let preferences: Preferences
  var onGesture: @MainActor () -> Void = {}
  private var detector: DoubleTapDetector?
  private var global: Any?
  private var local: Any?
  private var running = false

  init(preferences: Preferences) {
    self.preferences = preferences
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

  private func follow() {
    withObservationTracking {
      _ = preferences.gesture
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
    guard let modifier = preferences.gesture else { return }
    detector = DoubleTapDetector(modifier: modifier)
    let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
    global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
      let fed = Self.event(type: event.type, flags: event.modifierFlags, at: event.timestamp)
      MainActor.assumeIsolated { self?.feed(fed) }
    }
    local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
      let fed = Self.event(type: event.type, flags: event.modifierFlags, at: event.timestamp)
      MainActor.assumeIsolated { self?.feed(fed) }
      return event
    }
  }

  private func uninstall() {
    if let global { NSEvent.removeMonitor(global) }
    if let local { NSEvent.removeMonitor(local) }
    global = nil
    local = nil
    detector = nil
  }

  private func feed(_ event: ModifierEvent?) {
    guard let event, detector?.feed(event) == true else { return }
    onGesture()
  }
}

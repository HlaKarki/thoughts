import AppKit
import SwiftUI

extension KeyStroke {
  init?(event: NSEvent) {
    guard event.type == .keyDown else { return nil }
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    var modifiers: EventModifiers = []
    if flags.contains(.command) { modifiers.insert(.command) }
    if flags.contains(.shift) { modifiers.insert(.shift) }
    if flags.contains(.option) { modifiers.insert(.option) }
    if flags.contains(.control) { modifiers.insert(.control) }
    let key: KeyEquivalent
    switch event.keyCode {
    case 126: key = .upArrow
    case 125: key = .downArrow
    case 36, 76: key = .return
    case 53: key = .escape
    case 49: key = .space
    case 51: key = .delete
    default:
      guard let character = event.charactersIgnoringModifiers?.lowercased().first else {
        return nil
      }
      key = KeyEquivalent(character)
    }
    self.init(key: key, modifiers: modifiers)
  }
}

struct KeyRoutingView: NSViewRepresentable {
  let handle: (KeyStroke) -> Bool

  func makeNSView(context: Context) -> MonitorView {
    MonitorView()
  }

  func updateNSView(_ view: MonitorView, context: Context) {
    view.handle = handle
  }

  final class MonitorView: NSView {
    var handle: ((KeyStroke) -> Bool)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let monitor { NSEvent.removeMonitor(monitor) }
      monitor = nil
      guard window != nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        let consumed = MainActor.assumeIsolated { self?.consumes(event) ?? false }
        return consumed ? nil : event
      }
    }

    private func consumes(_ event: NSEvent) -> Bool {
      guard event.window === window, let stroke = KeyStroke(event: event) else { return false }
      if let editor = window?.firstResponder as? NSTextView, editor.hasMarkedText() {
        return false
      }
      return handle?(stroke) == true
    }
  }
}

import KeyboardShortcuts
import Observation

struct ShortcutSwitch {
  var register: @MainActor (@escaping @MainActor () -> Void) -> Void
  var unregister: @MainActor () -> Void
  var setEnabled: @MainActor (Bool) -> Void

  static let live = ShortcutSwitch(
    register: { handler in
      KeyboardShortcuts.onKeyUp(for: .capture) { MainActor.assumeIsolated { handler() } }
    },
    unregister: { KeyboardShortcuts.removeHandler(for: .capture) },
    setEnabled: { enabled in
      if enabled {
        KeyboardShortcuts.enable(.capture)
      } else {
        KeyboardShortcuts.disable(.capture)
      }
    })
}

@MainActor
final class CaptureShortcut {
  private let preferences: Preferences
  private let hotkey: ShortcutSwitch
  var onFire: @MainActor () -> Void = {}
  private var running = false

  init(preferences: Preferences, hotkey: ShortcutSwitch = .live) {
    self.preferences = preferences
    self.hotkey = hotkey
  }

  func start() {
    guard !running else { return }
    running = true
    hotkey.register { [weak self] in self?.fire() }
    apply()
    follow()
  }

  func stop() {
    guard running else { return }
    running = false
    hotkey.setEnabled(false)
    hotkey.unregister()
  }

  func apply() {
    hotkey.setEnabled(preferences.captureShortcut)
  }

  func fire() {
    guard running, preferences.captureShortcut else { return }
    onFire()
  }

  private func follow() {
    withObservationTracking {
      _ = preferences.captureShortcut
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self, self.running else { return }
        self.apply()
        self.follow()
      }
    }
  }
}

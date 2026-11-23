import Foundation
import Observation
import ThoughtsCore

@MainActor
@Observable
final class Preferences {
  @ObservationIgnored private let defaults: UserDefaults

  var edge: PanelEdge {
    didSet { defaults.set(edge.rawValue, forKey: Key.edge) }
  }

  var keepOpen: Bool {
    didSet { defaults.set(keepOpen, forKey: Key.keepOpen) }
  }

  var firstRunDone: Bool {
    didSet { defaults.set(firstRunDone, forKey: Key.firstRunDone) }
  }

  var gesture: Modifier? {
    didSet { defaults.set(gesture?.rawValue ?? Self.gestureOff, forKey: Key.gesture) }
  }

  var captureShortcut: Bool {
    didSet { defaults.set(captureShortcut, forKey: Key.captureShortcut) }
  }

  var soundEnabled: Bool {
    didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
  }

  var offersEnabled: Bool {
    didSet { defaults.set(offersEnabled, forKey: Key.offersEnabled) }
  }

  var showsMenuBarIcon: Bool {
    didSet { defaults.set(showsMenuBarIcon, forKey: Key.showsMenuBarIcon) }
  }

  var watchedFolders: [URL] {
    didSet { defaults.set(watchedFolders.map(\.path), forKey: Key.watchedFolders) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    edge = defaults.string(forKey: Key.edge).flatMap(PanelEdge.init(rawValue:)) ?? .right
    keepOpen = defaults.bool(forKey: Key.keepOpen)
    firstRunDone = defaults.bool(forKey: Key.firstRunDone)
    gesture =
      switch defaults.string(forKey: Key.gesture) {
      case nil: .shift
      case Self.gestureOff: nil
      case let raw?: Modifier(rawValue: raw) ?? .shift
      }
    captureShortcut = defaults.bool(forKey: Key.captureShortcut)
    soundEnabled = defaults.object(forKey: Key.soundEnabled) as? Bool ?? true
    offersEnabled = defaults.object(forKey: Key.offersEnabled) as? Bool ?? true
    showsMenuBarIcon = defaults.object(forKey: Key.showsMenuBarIcon) as? Bool ?? true
    watchedFolders = (defaults.stringArray(forKey: Key.watchedFolders) ?? []).map {
      URL(fileURLWithPath: $0, isDirectory: true)
    }
  }

  var captureMethod: CaptureMethod {
    get {
      if captureShortcut { return .shortcut }
      return gesture.map(CaptureMethod.doubleTap) ?? .off
    }
    set {
      switch newValue {
      case .doubleTap(let modifier):
        gesture = modifier
        captureShortcut = false
      case .shortcut:
        captureShortcut = true
      case .off:
        gesture = nil
        captureShortcut = false
      }
    }
  }

  private static let gestureOff = "off"

  private enum Key {
    static let edge = "panelEdge"
    static let keepOpen = "keepOpen"
    static let firstRunDone = "firstRunDone"
    static let gesture = "captureGesture"
    static let captureShortcut = "captureShortcut"
    static let soundEnabled = "soundEnabled"
    static let offersEnabled = "offersEnabled"
    static let showsMenuBarIcon = "showsMenuBarIcon"
    static let watchedFolders = "watchedFolders"
  }
}

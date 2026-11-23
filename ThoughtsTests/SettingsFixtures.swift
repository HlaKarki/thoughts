import AppKit
import Foundation
import Testing

@testable import Thoughts

@MainActor
final class FakeSystem {
  var trusted = false
  var access: NSPasteboard.AccessBehavior = .alwaysAllow
  var picks: [URL?] = []
  private(set) var requested = 0
  private(set) var opened: [URL] = []
  private(set) var revealed: [URL] = []
  private(set) var read: [URL] = []

  var services: SystemServices {
    SystemServices(
      accessibilityTrusted: { self.trusted },
      requestAccessibility: { self.requested += 1 },
      open: { self.opened.append($0) },
      reveal: { self.revealed.append($0) },
      pasteboardAccess: { self.access },
      chooseFolder: { _, _ in self.picks.isEmpty ? nil : self.picks.removeFirst() },
      readFolder: { self.read.append($0) })
  }
}

final class CallLog: @unchecked Sendable {
  private let lock = NSLock()
  private var items: [String] = []

  var events: [String] {
    lock.lock()
    defer { lock.unlock() }
    return items
  }

  func add(_ event: String) {
    lock.lock()
    items.append(event)
    lock.unlock()
  }
}

@MainActor
final class FakeLogin {
  var status = LoginStatus.off
  var failure: Error?
  private(set) var openedSettings = 0

  var control: LoginControl {
    LoginControl(
      status: { self.status },
      set: { enabled in
        if let failure = self.failure { throw failure }
        self.status = enabled ? .on : .off
      },
      openSettings: { self.openedSettings += 1 })
  }
}

enum SettingsFixtures {
  static let home = URL(fileURLWithPath: "/example/home", isDirectory: true)

  @MainActor
  static func preferences() throws -> Preferences {
    let name = "thoughts.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    return Preferences(defaults: defaults)
  }

  static func screenshots() throws -> ScreenshotLocation {
    let name = "thoughts.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    return ScreenshotLocation(defaults: defaults, home: home, isFolder: { _ in true })
  }

  static func mover(
    folder: URL = home.appendingPathComponent("Thoughts", isDirectory: true),
    log: CallLog = CallLog(), exists: @escaping @Sendable (URL) -> Bool = { _ in true }
  ) -> StorageMover {
    StorageMover(
      current: { folder },
      stop: { log.add("stop") },
      apply: { log.add("apply \($0.path)") },
      relocate: { log.add("relocate \($0.path)") },
      restart: { log.add("restart") },
      exists: exists,
      point: { log.add("point \($0.path)") })
  }

  @MainActor
  static func firstRun(
    system: FakeSystem, preferences: Preferences, mover: StorageMover = mover(),
    summonKeySet: Bool = true, captureShortcutText: String? = nil
  ) throws -> FirstRunModel {
    FirstRunModel(
      preferences: preferences, services: system.services, storage: mover,
      screenshots: try screenshots(), home: home, pollInterval: .milliseconds(1),
      summonKeySet: { summonKeySet }, captureShortcutText: { captureShortcutText })
  }

  @MainActor
  static func settings(
    system: FakeSystem, preferences: Preferences, login: FakeLogin = FakeLogin(),
    mover: StorageMover = mover()
  ) throws -> SettingsModel {
    SettingsModel(
      preferences: preferences, services: system.services, login: login.control, storage: mover,
      screenshots: try screenshots(), home: home)
  }
}

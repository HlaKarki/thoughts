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
  let folderReads = FolderReads()

  var read: [URL] { folderReads.urls }

  var services: SystemServices {
    SystemServices(
      accessibilityTrusted: { self.trusted },
      requestAccessibility: { self.requested += 1 },
      open: { self.opened.append($0) },
      reveal: { self.revealed.append($0) },
      pasteboardAccess: { self.access },
      chooseFolder: { _, _ in self.picks.isEmpty ? nil : self.picks.removeFirst() },
      readFolder: { [folderReads] in folderReads.read($0) })
  }
}

final class FolderReads: @unchecked Sendable {
  private let lock = NSLock()
  private var seen: [(url: URL, onMain: Bool)] = []
  private var hold: Hold?

  var urls: [URL] { lock.withLock { seen.map(\.url) } }
  var anyOnMain: Bool { lock.withLock { seen.contains { $0.onMain } } }

  func holdEachRead(with hold: Hold = Hold()) {
    lock.withLock { self.hold = hold }
  }

  func releaseHeldReads() {
    lock.withLock { hold }?.release()
  }

  func read(_ url: URL) {
    lock.withLock { seen.append((url, Thread.isMainThread)) }
    lock.withLock { hold }?.pass()
  }
}

final class Hold: @unchecked Sendable {
  private let condition = NSCondition()
  private let first: Int
  private var count = 0
  private var released = false
  private var times: [ContinuousClock.Instant] = []

  init(first: Int = .max) {
    self.first = first
  }

  var arrived: Int { condition.withLock { count } }

  func arrival(_ number: Int) -> ContinuousClock.Instant? {
    condition.withLock { times.count >= number ? times[number - 1] : nil }
  }

  func pass() {
    condition.withLock {
      count += 1
      times.append(.now)
      guard count <= first else { return }
      let deadline = Date().addingTimeInterval(5)
      while !released, condition.wait(until: deadline) {}
    }
  }

  func release() {
    condition.withLock {
      released = true
      condition.broadcast()
    }
  }

  func waitForArrivals(_ wanted: Int) async {
    for _ in 0..<250 where arrived < wanted {
      try? await Task.sleep(for: .milliseconds(20))
    }
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
    let defaults = try Throwaway.defaults()
    return Preferences(defaults: defaults)
  }

  static func screenshots() throws -> ScreenshotLocation {
    let defaults = try Throwaway.defaults()
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
      screenshots: try screenshots(), home: home,
      pollInterval: .milliseconds(1),
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

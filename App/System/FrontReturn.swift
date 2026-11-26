import AppKit
import ThoughtsCore

@MainActor
final class FrontReturn {
  static let systemSettings = "com.apple.systempreferences"
  static let folderPrompt = "com.apple.UserNotificationCenter"
  static let accessibilityAlert = "com.apple.accessibility.universalAccessAuthWarn"
  nonisolated static let recheckAfter: Duration = .milliseconds(300)

  struct Hooks {
    var openedSystemSettings: @MainActor () -> Void = {}
    var askedForAccessibility: @MainActor () -> Void = {}
    var read: @MainActor () -> @MainActor () -> Void = { {} }
  }

  private enum Role {
    case own
    case settings
    case prompt
    case other
  }

  @MainActor
  private final class Watch {
    let back: @MainActor () -> Void
    let otherwise: @MainActor () -> Void
    let yieldsToSettings: Bool
    let started: Date
    var prompt: AppSnapshot?
    var promptGone = false
    var readDone: Bool
    var check: Task<Void, Never>?

    init(
      back: @escaping @MainActor () -> Void, otherwise: @escaping @MainActor () -> Void,
      yieldsToSettings: Bool, started: Date, readDone: Bool
    ) {
      self.back = back
      self.otherwise = otherwise
      self.yieldsToSettings = yieldsToSettings
      self.started = started
      self.readDone = readDone
    }
  }

  private struct SettingsReturn {
    let back: @MainActor () -> Void
    var active = false
    var fallbackSeen = false
    var pid: Int32?
  }

  private let center: NotificationCenter
  private let ownBundleID: String?
  private let frontmost: @MainActor () -> AppSnapshot?
  private let app: @Sendable (Notification) -> AppSnapshot?
  private let showsWindow: @MainActor (Int32) -> Bool
  private let settingsLaunched: @MainActor (Date) -> Bool
  private let recheckDelay: @Sendable () async throws -> Void
  private let now: @MainActor () -> Date
  private var settingsReturn: SettingsReturn?
  private var watches: [Watch] = []
  private var observers: [NSObjectProtocol] = []

  init(
    center: NotificationCenter = NSWorkspace.shared.notificationCenter,
    ownBundleID: String? = Bundle.main.bundleIdentifier,
    frontmost: @escaping @MainActor () -> AppSnapshot? = FrontReturn.frontmostApp,
    app: @escaping @Sendable (Notification) -> AppSnapshot? = FrontReturn.app(in:),
    showsWindow: @escaping @MainActor (Int32) -> Bool = FrontReturn.showsWindow(pid:),
    settingsLaunched: @escaping @MainActor (Date) -> Bool = FrontReturn.settingsLaunched(since:),
    recheckDelay: @escaping @Sendable () async throws -> Void = {
      try await Task.sleep(for: FrontReturn.recheckAfter)
    },
    now: @escaping @MainActor () -> Date = Date.init
  ) {
    self.center = center
    self.ownBundleID = ownBundleID
    self.frontmost = frontmost
    self.app = app
    self.showsWindow = showsWindow
    self.settingsLaunched = settingsLaunched
    self.recheckDelay = recheckDelay
    self.now = now
  }

  func hooks(_ back: @escaping @MainActor () -> Void) -> Hooks {
    Hooks(
      openedSystemSettings: { [weak self] in
        guard let self, ownIsFront else { return }
        armSettings(back)
      },
      askedForAccessibility: { [weak self] in
        guard let self, ownIsFront else { return }
        armSettings(back)
        begin(
          Watch(
            back: back, otherwise: {}, yieldsToSettings: true, started: now(), readDone: true))
      },
      read: { [weak self] in
        guard let self, ownIsFront else { return {} }
        return watchRead(back: back, otherwise: {})
      })
  }

  func watchRead(
    back: @escaping @MainActor () -> Void, otherwise: @escaping @MainActor () -> Void
  ) -> @MainActor () -> Void {
    let watch = Watch(
      back: back, otherwise: otherwise, yieldsToSettings: false, started: now(), readDone: false)
    begin(watch)
    return { [weak self] in self?.readFinished(watch) }
  }

  private var ownIsFront: Bool {
    guard let ownBundleID else { return false }
    return frontmost()?.bundleID == ownBundleID
  }

  private func armSettings(_ back: @escaping @MainActor () -> Void) {
    settingsReturn = SettingsReturn(back: back)
    listen()
  }

  private func begin(_ watch: Watch) {
    if let front = frontmost(), role(of: front) == .prompt, showsWindow(front.pid) {
      watch.prompt = front
    }
    watches.append(watch)
    listen()
  }

  private func readFinished(_ watch: Watch) {
    guard isPending(watch), !watch.readDone else { return }
    watch.readDone = true
    if watch.prompt == nil {
      end(watch, back: false)
    } else if watch.promptGone {
      end(watch, back: true)
    }
  }

  private func isPending(_ watch: Watch) -> Bool {
    watches.contains { $0 === watch }
  }

  private func end(_ watch: Watch, back: Bool) {
    guard let index = watches.firstIndex(where: { $0 === watch }) else { return }
    watches.remove(at: index)
    watch.check?.cancel()
    watch.check = nil
    if back { watch.back() } else { watch.otherwise() }
    quietIfIdle()
  }

  private func listen() {
    guard observers.isEmpty else { return }
    let app = app
    let names = [
      NSWorkspace.didActivateApplicationNotification,
      NSWorkspace.didHideApplicationNotification,
      NSWorkspace.didTerminateApplicationNotification,
    ]
    observers = names.map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
        guard let changed = app(note) else { return }
        MainActor.assumeIsolated { self?.receive(name, changed) }
      }
    }
  }

  private func quietIfIdle() {
    guard settingsReturn == nil, watches.isEmpty else { return }
    for observer in observers { center.removeObserver(observer) }
    observers = []
  }

  private func receive(_ name: Notification.Name, _ app: AppSnapshot) {
    let role = role(of: app)
    switch name {
    case NSWorkspace.didActivateApplicationNotification:
      settingsSaw(app, role)
      for watch in watches { step(watch, activated: app, role) }
    case NSWorkspace.didHideApplicationNotification where role == .settings:
      settingsReturn?.active = false
    case NSWorkspace.didTerminateApplicationNotification where role == .settings:
      settingsTerminated()
    default:
      break
    }
    quietIfIdle()
  }

  private func settingsSaw(_ app: AppSnapshot, _ role: Role) {
    guard var settings = settingsReturn else { return }
    switch role {
    case .settings:
      settings.active = true
      settings.fallbackSeen = false
      settings.pid = app.pid
    case .own:
      settings.active = false
    case .prompt:
      break
    case .other:
      if settings.active, !settings.fallbackSeen, let pid = settings.pid, !showsWindow(pid) {
        settings.fallbackSeen = true
      } else {
        settings.active = false
      }
    }
    settingsReturn = settings
  }

  private func settingsTerminated() {
    guard let settings = settingsReturn else { return }
    settingsReturn = nil
    if settings.active { settings.back() }
  }

  private func step(_ watch: Watch, activated app: AppSnapshot, _ role: Role) {
    let checking = watch.check != nil
    watch.check?.cancel()
    watch.check = nil
    switch role {
    case .prompt:
      watch.prompt = app
      watch.promptGone = false
    case .own:
      end(watch, back: false)
    case .settings, .other:
      if yields(watch, activated: role) || checking {
        end(watch, back: false)
      } else if let prompt = watch.prompt, !watch.promptGone {
        if showsWindow(prompt.pid) { recheck(watch, prompt) } else { promptLeft(watch) }
      } else {
        end(watch, back: false)
      }
    }
  }

  private func yields(_ watch: Watch, activated role: Role?) -> Bool {
    guard watch.yieldsToSettings else { return false }
    return role == .settings || settingsLaunched(watch.started)
  }

  private func promptLeft(_ watch: Watch) {
    watch.promptGone = true
    if watch.readDone { end(watch, back: true) }
  }

  private func recheck(_ watch: Watch, _ prompt: AppSnapshot) {
    watch.check = Task { [weak self, weak watch, recheckDelay] in
      do { try await recheckDelay() } catch { return }
      guard !Task.isCancelled, let self, let watch else { return }
      checked(watch, prompt)
    }
  }

  private func checked(_ watch: Watch, _ prompt: AppSnapshot) {
    guard isPending(watch) else { return }
    watch.check = nil
    if yields(watch, activated: nil) || showsWindow(prompt.pid) {
      end(watch, back: false)
    } else {
      promptLeft(watch)
    }
  }

  private func role(of app: AppSnapshot) -> Role {
    if let ownBundleID, app.bundleID == ownBundleID { return .own }
    switch app.bundleID {
    case Self.systemSettings: return .settings
    case Self.folderPrompt, Self.accessibilityAlert: return .prompt
    default: return .other
    }
  }

  static func frontmostApp() -> AppSnapshot? {
    NSWorkspace.shared.frontmostApplication.map(FrontmostTracker.snapshot)
  }

  nonisolated static func app(in note: Notification) -> AppSnapshot? {
    (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
      .map(FrontmostTracker.snapshot)
  }

  static func showsWindow(pid: Int32) -> Bool {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
    else { return false }
    return list.contains { info in
      guard (info[kCGWindowOwnerPID as String] as? Int32) == pid,
        (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
        let bounds = info[kCGWindowBounds as String] as? NSDictionary,
        let rect = CGRect(dictionaryRepresentation: bounds)
      else { return false }
      return rect.width > 1 && rect.height > 1
    }
  }

  static func settingsLaunched(since start: Date) -> Bool {
    NSRunningApplication.runningApplications(withBundleIdentifier: systemSettings).contains {
      ($0.launchDate ?? .distantPast) >= start
    }
  }
}

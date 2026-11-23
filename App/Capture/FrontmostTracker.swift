import AppKit
import ThoughtsCore

@MainActor
final class FrontmostTracker {
  static let capacity = 8

  let ownBundleID: String
  private let workspace: NSWorkspace
  private var observer: NSObjectProtocol?
  private(set) var history: [AppSnapshot] = []

  init(workspace: NSWorkspace = .shared, ownBundleID: String) {
    self.workspace = workspace
    self.ownBundleID = ownBundleID
  }

  var frontmost: AppSnapshot? {
    workspace.frontmostApplication.map(Self.snapshot)
  }

  func start() {
    guard observer == nil else { return }
    if let frontmost { record(frontmost) }
    observer = workspace.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] note in
      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      guard let snapshot = app.map(Self.snapshot) else { return }
      MainActor.assumeIsolated { self?.record(snapshot) }
    }
  }

  func record(_ app: AppSnapshot) {
    history.removeAll { $0.pid == app.pid }
    history.append(app)
    if history.count > Self.capacity { history.removeFirst(history.count - Self.capacity) }
  }

  nonisolated static func snapshot(_ app: NSRunningApplication) -> AppSnapshot {
    AppSnapshot(
      pid: app.processIdentifier, bundleID: app.bundleIdentifier, name: app.localizedName)
  }
}

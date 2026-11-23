import Foundation
import ThoughtsCore

@MainActor
final class InboxImporter {
  static let appGroup = Bundle.main.object(forInfoDictionaryKey: "ThoughtsAppGroup") as? String

  var onFailure: (String) -> Void = { _ in }
  private let inbox: Inbox
  private let save: (NewThought) async throws -> Void
  private let source: () async -> Source?
  private let queue = DispatchQueue(label: "thoughts.inbox")
  private var watcher: FolderWatcher?
  private var running: Task<Void, Never>?
  private var requested = false

  init(
    inbox: Inbox, save: @escaping (NewThought) async throws -> Void,
    source: @escaping () async -> Source?
  ) {
    self.inbox = inbox
    self.save = save
    self.source = source
  }

  static func groupInbox() -> Inbox? {
    guard let appGroup, !appGroup.isEmpty,
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroup)
    else { return nil }
    return Inbox(folder: container.appendingPathComponent("Inbox", isDirectory: true))
  }

  func start() {
    guard watcher == nil else { return }
    try? FileManager.default.createDirectory(at: inbox.folder, withIntermediateDirectories: true)
    let watcher = FolderWatcher(folder: inbox.folder, queue: queue) { [weak self] _ in
      Task { @MainActor in self?.importNow() }
    }
    try? watcher.start()
    self.watcher = watcher
    importNow()
  }

  func stop() {
    watcher?.stop()
    watcher = nil
  }

  @discardableResult
  func importNow() -> Task<Void, Never> {
    requested = true
    if let running { return running }
    let task = Task { [weak self] in
      while let self, self.requested {
        self.requested = false
        await self.importPending()
      }
      self?.running = nil
    }
    running = task
    return task
  }

  private func importPending() async {
    guard let entries = try? inbox.pending(), !entries.isEmpty else { return }
    let fallback = await source()
    var failure: String?
    for entry in entries {
      guard let new = try? inbox.newThought(from: entry, source: fallback) else { continue }
      do {
        try await save(new)
        try inbox.remove(entry)
      } catch {
        failure = failure ?? CaptureCoordinator.message(for: error)
      }
    }
    if let failure { onFailure(failure) }
  }
}

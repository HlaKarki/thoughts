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
    let watcher = FolderWatcher(folder: inbox.folder, queue: queue) { [weak self] _ in
      Task { @MainActor in self?.importNow() }
    }
    do {
      try FileManager.default.createDirectory(
        at: inbox.folder, withIntermediateDirectories: true)
      try watcher.start()
    } catch {
      onFailure(String(localized: "Shared items won't arrive until you reopen Thoughts"))
    }
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

  private func discard(_ entry: URL) {
    if inbox.isReadable(entry) {
      try? inbox.remove(entry)
    } else {
      try? inbox.quarantine(entry)
    }
  }

  private func importPending() async {
    let entries: [URL]
    do {
      entries = try inbox.pending()
    } catch {
      onFailure(String(localized: "Couldn't read the shared items"))
      return
    }
    guard !entries.isEmpty else { return }
    let fallback = await source()
    var failure: String?
    for entry in entries {
      let new: NewThought
      do {
        new = try inbox.newThought(from: entry, source: fallback)
      } catch {
        failure = failure ?? CaptureCoordinator.message(for: error)
        discard(entry)
        continue
      }
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

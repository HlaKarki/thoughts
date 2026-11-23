import Foundation
import Synchronization

public final class LiveIndex: @unchecked Sendable {
  private final class Session: @unchecked Sendable {
    let watcher: FolderWatcher
    let sync: IndexSync
    let store: ThoughtStore
    let cancellation: CancellationFlag
    let root: String
    let onChange: @Sendable (Result<IndexChanges, ThoughtsError>) -> Void
    var active = true

    init(
      watcher: FolderWatcher, sync: IndexSync, store: ThoughtStore,
      cancellation: CancellationFlag, root: String,
      onChange: @escaping @Sendable (Result<IndexChanges, ThoughtsError>) -> Void
    ) {
      self.watcher = watcher
      self.sync = sync
      self.store = store
      self.cancellation = cancellation
      self.root = root
      self.onChange = onChange
    }
  }

  private static let queueKey = DispatchSpecificKey<Void>()

  private let location: StorageLocation
  private let index: SearchIndex
  private let recognizer: (any TextRecognizing)?
  private let queue = DispatchQueue(label: "thoughts.live-index")
  private var session: Session?
  private let pending = Mutex<CancellationFlag?>(nil)
  private var handler: (@Sendable (Result<IndexChanges, ThoughtsError>) -> Void)?

  public init(location: StorageLocation, index: SearchIndex, recognizer: (any TextRecognizing)?) {
    self.location = location
    self.index = index
    self.recognizer = recognizer
    queue.setSpecific(key: Self.queueKey, value: ())
  }

  deinit {
    session?.active = false
    session?.watcher.stop()
  }

  public func start(
    onChange: @escaping @Sendable (Result<IndexChanges, ThoughtsError>) -> Void
  ) throws {
    try onQueue {
      self.handler = onChange
      try self.begin(onChange)
    }
  }

  public func restart() throws {
    cancelRunningPass()
    try onQueue {
      guard let handler = self.handler else {
        throw ThoughtsError.io("The live index was never started")
      }
      self.end()
      try self.begin(handler)
    }
  }

  public func stop() {
    cancelRunningPass()
    try? onQueue { self.end() }
  }

  private func onQueue(_ body: () throws -> Void) throws {
    if DispatchQueue.getSpecific(key: Self.queueKey) != nil {
      try body()
    } else {
      try queue.sync(execute: body)
    }
  }

  private func cancelRunningPass() {
    pending.withLock { $0?.cancel() }
  }

  private func end() {
    guard let session else { return }
    session.cancellation.cancel()
    session.active = false
    session.watcher.stop()
    self.session = nil
  }

  private func begin(
    _ onChange: @escaping @Sendable (Result<IndexChanges, ThoughtsError>) -> Void
  ) throws {
    guard session == nil else { return }
    let folder = try location.resolve()
    let store = ThoughtStore(folder: folder)
    let cancellation = CancellationFlag()
    var sync = IndexSync(store: store, index: index, recognizer: recognizer)
    sync.cancellation = cancellation
    let watcher = FolderWatcher(folder: folder, latency: 0.2, queue: queue) { [weak self] events in
      self?.handle(events)
    }
    try watcher.start()
    let session = Session(
      watcher: watcher,
      sync: sync,
      store: store,
      cancellation: cancellation,
      root: FolderWatcher.canonicalPath(folder),
      onChange: onChange)
    self.session = session
    pending.withLock { $0 = cancellation }
    let listing = IndexSync(store: store, index: index, recognizer: nil)
    queue.async { [weak self] in
      guard let self, session.active else { return }
      self.deliver(session) { try listing.reconcile(nil) }
      guard self.recognizer != nil, session.active else { return }
      self.deliver(session) { try session.sync.reconcile(nil) }
    }
  }

  private func handle(_ events: [WatchEvent]) {
    guard let session, session.active else { return }
    deliver(session) {
      guard let files = try self.files(for: events, in: session) else {
        return try session.sync.reconcile(nil)
      }
      return files.isEmpty ? IndexChanges() : try session.sync.reconcile(files)
    }
  }

  private func deliver(_ session: Session, _ work: () throws -> IndexChanges) {
    let result: Result<IndexChanges, ThoughtsError>
    do {
      result = .success(try work())
    } catch let error as ThoughtsError {
      result = .failure(error)
    } catch {
      result = .failure(.io(error.localizedDescription))
    }
    guard session.active else { return }
    if case .success(let changes) = result, changes.isEmpty { return }
    session.onChange(result)
  }

  private func files(for events: [WatchEvent], in session: Session) throws -> [URL]? {
    var files: [String] = []
    var documents: [String]?
    for event in events {
      if event.forcesFullScan { return nil }
      guard event.url.deletingLastPathComponent().path == session.root else { continue }
      let name = event.url.lastPathComponent
      if IndexSync.isMarkdownName(name) {
        files.append(name)
        continue
      }
      let all = try documents ?? session.store.markdownNames()
      documents = all
      let base = IndexSync.ReconcilePlan.folded((name as NSString).deletingPathExtension)
      let partners = all.filter {
        IndexSync.ReconcilePlan.folded(($0 as NSString).deletingPathExtension) == base
      }
      if partners.isEmpty { return nil }
      files.append(contentsOf: partners)
    }
    return Set(files).sorted().map { session.store.folder.appendingPathComponent($0) }
  }
}

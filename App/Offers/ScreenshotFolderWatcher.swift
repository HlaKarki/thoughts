import Foundation
import ThoughtsCore
import UniformTypeIdentifiers

@MainActor
final class ScreenshotFolderWatcher {
  static let settleInterval: Duration = .milliseconds(250)
  static let maxReads = 40

  private final class Watch {
    let folder: URL
    let watcher: FolderWatcher
    let started: Date
    var known: Set<String>
    var pending: [String: Task<Void, Never>] = [:]

    init(folder: URL, watcher: FolderWatcher, started: Date, known: Set<String>) {
      self.folder = folder
      self.watcher = watcher
      self.started = started
      self.known = known
    }
  }

  private let storageFolder: () -> URL?
  private let listFolder: @Sendable (URL) -> [String]
  private let now: () -> Date
  private let settle: Duration
  private let queue = DispatchQueue(label: "thoughts.screenshot-folders")
  private var watches: [String: Watch] = [:]
  private var updating: Task<Void, Never>?
  private var generation = 0

  var onFile: (URL, Date) -> Void = { _, _ in }

  init(
    storageFolder: @escaping () -> URL?, now: @escaping () -> Date = Date.init,
    settle: Duration = ScreenshotFolderWatcher.settleInterval,
    listFolder: @escaping @Sendable (URL) -> [String] = ScreenshotFolderWatcher.list
  ) {
    self.storageFolder = storageFolder
    self.listFolder = listFolder
    self.now = now
    self.settle = settle
  }

  var watchedFolders: [URL] {
    watches.values.map(\.folder).sorted { $0.path < $1.path }
  }

  nonisolated static func list(_ folder: URL) -> [String] {
    (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
  }

  func update(folders: [URL]) {
    let storage = storageFolder()
    let previous = updating
    generation += 1
    let generation = generation
    updating = Task { [weak self] in
      await previous?.value
      guard self?.generation == generation else { return }
      let wanted = await Task.detached { Self.wanted(folders, storage: storage) }.value
      guard let self, self.generation == generation else { return }
      for key in self.watches.keys where wanted[key] == nil { self.end(key) }
      for (key, folder) in wanted.sorted(by: { $0.key < $1.key }) where self.watches[key] == nil {
        guard self.generation == generation else { return }
        await self.begin(key, folder, generation: generation)
      }
    }
  }

  func caughtUp() async {
    await updating?.value
  }

  func stop() {
    generation += 1
    for key in Array(watches.keys) { end(key) }
  }

  nonisolated private static func wanted(_ folders: [URL], storage: URL?) -> [String: URL] {
    let storage = storage.map(key)
    var wanted: [String: URL] = [:]
    for folder in folders {
      let key = key(folder)
      if key != storage, wanted[key] == nil { wanted[key] = folder }
    }
    return wanted
  }

  private func begin(_ key: String, _ folder: URL, generation: Int) async {
    let started = now()
    let list = listFolder
    let queue = queue
    let opened = await Task.detached { [weak self] () -> (Set<String>, FolderWatcher)? in
      let existing = Set(list(folder))
      let watcher = FolderWatcher(folder: folder, queue: queue) { [weak self] urls in
        Task { @MainActor in self?.handle(urls, key: key) }
      }
      do {
        try watcher.start()
      } catch {
        return nil
      }
      return (existing, watcher)
    }.value
    guard let opened else { return }
    let (existing, watcher) = opened
    guard self.generation == generation, watches[key] == nil else {
      watcher.stop()
      return
    }
    watches[key] = Watch(folder: folder, watcher: watcher, started: started, known: existing)
  }

  private func end(_ key: String) {
    guard let watch = watches.removeValue(forKey: key) else { return }
    watch.watcher.stop()
    for task in watch.pending.values { task.cancel() }
  }

  func handle(_ urls: [URL], key: String) {
    guard let watch = watches[key] else { return }
    var names: [String] = []
    for url in urls {
      if Self.isDirectory(url) {
        names.append(contentsOf: listFolder(watch.folder))
      } else if Self.key(url.deletingLastPathComponent()) == key {
        names.append(url.lastPathComponent)
      }
    }
    for name in names where Self.isCandidate(name: name, in: watch) {
      watch.known.insert(name)
      let file = watch.folder.appendingPathComponent(name)
      watch.pending[name] = Task { [weak self, weak watch] in
        guard let self, await self.holdsSize(file) else { return }
        self.onFile(file, self.now())
        watch?.pending[name] = nil
      }
    }
  }

  private static func isCandidate(name: String, in watch: Watch) -> Bool {
    guard !name.hasPrefix("."), !watch.known.contains(name) else { return false }
    let file = watch.folder.appendingPathComponent(name)
    guard UTType(filenameExtension: file.pathExtension)?.conforms(to: .image) == true,
      let values = try? file.resourceValues(forKeys: [.creationDateKey, .isRegularFileKey]),
      values.isRegularFile == true, let created = values.creationDate
    else { return false }
    return created >= watch.started
  }

  private func holdsSize(_ file: URL) async -> Bool {
    var previous = Self.size(of: file)
    for _ in 0..<Self.maxReads {
      try? await Task.sleep(for: settle)
      guard !Task.isCancelled else { return false }
      let current = Self.size(of: file)
      if let current, current > 0, current == previous { return true }
      if current == nil, previous == nil { return false }
      previous = current
    }
    return false
  }

  private static func size(of file: URL) -> Int? {
    (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
  }

  private static func isDirectory(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
  }

  nonisolated static func key(_ url: URL) -> String {
    url.resolvingSymlinksInPath().standardizedFileURL.path
  }
}

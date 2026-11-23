import Foundation
import Observation
import ThoughtsCore

extension ThoughtEntry {
  var file: URL {
    switch self {
    case .thought(let thought): thought.file
    case .malformed(let file, _): file
    }
  }

  var fileName: String { file.lastPathComponent }

  var isCleared: Bool {
    if case .thought(let thought) = self { thought.cleared } else { false }
  }
}

@MainActor
@Observable
final class ListModel {
  @ObservationIgnored private let index: SearchIndex
  @ObservationIgnored private let live: LiveIndex
  @ObservationIgnored private let location: StorageLocation
  @ObservationIgnored private var hintTask: Task<Void, Never>?
  @ObservationIgnored private var birthDates: [String: Date] = [:]
  @ObservationIgnored var onCommand: ((KeyCommand) -> Void)?

  private(set) var entries: [ThoughtEntry] = []
  private(set) var hint: String?
  private(set) var addedCount = 0
  private(set) var matches: Set<String>?
  var now = Date()
  var selection: [String] = []
  var focus: Focus = .input
  var query = "" {
    didSet {
      guard query != oldValue else { return }
      refreshMatches()
      pruneSelection()
    }
  }

  init(index: SearchIndex, live: LiveIndex, location: StorageLocation) {
    self.index = index
    self.live = live
    self.location = location
  }

  var visible: [ThoughtEntry] {
    guard let matches else { return entries.filter { !$0.isCleared } }
    return entries.filter { entry in
      guard case .thought(let thought) = entry else { return false }
      return matches.contains(thought.id.rawValue)
    }
  }

  var isSearching: Bool {
    !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var selectedEntries: [ThoughtEntry] {
    let chosen = Set(selection)
    return visible.filter { chosen.contains($0.fileName) }
  }

  func start() {
    load()
    do {
      try live.start { [weak self] result in
        Task { @MainActor in self?.receive(result) }
      }
    } catch let error as ThoughtsError {
      showHint(Self.message(for: error))
    } catch {
      showHint(error.localizedDescription)
    }
  }

  func load() {
    do {
      entries = try index.entries(includeCleared: true)
      now = Date()
      refreshMatches()
      pruneSelection()
    } catch let error as ThoughtsError {
      showHint(Self.message(for: error))
    } catch {
      showHint(error.localizedDescription)
    }
  }

  func apply(_ changes: IndexChanges) {
    guard !changes.isEmpty else { return }
    let held = Set(entries.map(\.fileName))
    load()
    if entries.contains(where: { !held.contains($0.fileName) }) { addedCount += 1 }
  }

  func date(of entry: ThoughtEntry) -> Date? {
    switch entry {
    case .thought(let thought):
      return thought.created
    case .malformed(let file, _):
      if let known = birthDates[file.lastPathComponent] { return known }
      let born = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate
      if let born { birthDates[file.lastPathComponent] = born }
      return born
    }
  }

  func moveSelection(by delta: Int, extend: Bool) {
    let names = visible.map(\.fileName)
    guard !names.isEmpty else { return }
    guard let anchor = selection.first.flatMap(names.firstIndex(of:)) else {
      selection = [names[0]]
      return
    }
    let cursor = selection.last.flatMap(names.firstIndex(of:)) ?? anchor
    let target = min(max(cursor + delta, 0), names.count - 1)
    selection = extend ? Self.range(from: anchor, to: target, in: names) : [names[target]]
  }

  func select(_ name: String, extend: Bool) {
    focus = .list
    let names = visible.map(\.fileName)
    guard let target = names.firstIndex(of: name) else { return }
    guard extend, let anchor = selection.first.flatMap(names.firstIndex(of:)) else {
      selection = [name]
      return
    }
    selection = Self.range(from: anchor, to: target, in: names)
  }

  func perform(_ command: KeyCommand) {
    switch command {
    case .move(let delta):
      focus = .list
      moveSelection(by: delta, extend: false)
    case .extend(let delta):
      moveSelection(by: delta, extend: true)
    case .selectNewest:
      guard let newest = visible.last else { return }
      focus = .list
      selection = [newest.fileName]
    case .focusSearch:
      focus = .search
    case .clearSearch:
      query = ""
      focus = .input
    case .backToInput:
      selection = []
      focus = .input
    default:
      break
    }
    onCommand?(command)
  }

  func clearDone() {
    let folder: URL
    do {
      folder = try location.resolve()
    } catch let error as ThoughtsError {
      showHint(Self.message(for: error))
      return
    } catch {
      showHint(error.localizedDescription)
      return
    }
    let store = ThoughtStore(folder: folder)
    Task {
      do {
        _ = try await Task.detached { try store.clearDone() }.value
      } catch let error as ThoughtsError {
        showHint(Self.message(for: error))
      } catch {
        showHint(error.localizedDescription)
      }
    }
  }

  func showHint(_ text: String) {
    hintTask?.cancel()
    hint = text
    hintTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(4))
      guard !Task.isCancelled else { return }
      self?.hint = nil
    }
  }

  private func receive(_ result: Result<IndexChanges, ThoughtsError>) {
    switch result {
    case .success(let changes): apply(changes)
    case .failure(let error): showHint(Self.message(for: error))
    }
  }

  private func refreshMatches() {
    guard isSearching else {
      matches = nil
      return
    }
    do {
      matches = Set(try index.search(query).map(\.rawValue))
    } catch let error as ThoughtsError {
      matches = []
      showHint(Self.message(for: error))
    } catch {
      matches = []
      showHint(error.localizedDescription)
    }
  }

  private func pruneSelection() {
    let names = Set(visible.map(\.fileName))
    let kept = selection.filter { names.contains($0) }
    if kept != selection { selection = kept }
  }

  private static func range(from anchor: Int, to cursor: Int, in names: [String]) -> [String] {
    let step = cursor >= anchor ? 1 : -1
    return stride(from: anchor, through: cursor, by: step).map { names[$0] }
  }

  static func message(for error: ThoughtsError) -> String {
    switch error {
    case .storageUnavailable(let path):
      String(localized: "The thoughts folder isn't available: \(path)")
    case .notFound:
      String(localized: "That thought isn't there anymore")
    case .ambiguous:
      String(localized: "More than one thought matches")
    case .changedOnDisk:
      String(localized: "That thought changed on disk")
    case .deletedOnDisk:
      String(localized: "That thought was deleted")
    case .folderNotEmpty:
      String(localized: "The folder isn't empty")
    case .clipboardChanged:
      String(localized: "The clipboard changed")
    case .io(let detail):
      detail
    }
  }
}

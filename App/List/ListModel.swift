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

  var thought: Thought? {
    if case .thought(let thought) = self { thought } else { nil }
  }

  var isCleared: Bool {
    if case .thought(let thought) = self { thought.cleared } else { false }
  }
}

struct EditSession: Equatable {
  let name: String
  let id: ThoughtID
  let file: URL
  var version: FileVersion
  let original: String
  let allowsBlank: Bool
  var text: String
  var isSaving = false
}

enum EditOutcome: Sendable {
  case saved(Thought)
  case changed(Thought?)
  case deleted
  case failed(String)
}

@MainActor
@Observable
final class ListModel {
  @ObservationIgnored private let index: SearchIndex
  @ObservationIgnored private let live: LiveIndex
  @ObservationIgnored private let location: StorageLocation
  @ObservationIgnored private let probe: StorageProbe
  @ObservationIgnored private let mounts: MountSignal
  @ObservationIgnored private var isRetryingStorage = false
  @ObservationIgnored private var keepsFeedback = false
  @ObservationIgnored private var feedbackTask: Task<Void, Never>?
  @ObservationIgnored private let feedbackDelay: @Sendable (Duration) async throws -> Void
  @ObservationIgnored private var birthDates: [String: Date] = [:]
  @ObservationIgnored private var searchTask: Task<Void, Never>?
  @ObservationIgnored private var queuedSelect: (name: String, extend: Bool)?
  @ObservationIgnored private var pendingReveal: [String] = []
  @ObservationIgnored private var isRevealing = false
  @ObservationIgnored private var restored: Set<String> = []
  @ObservationIgnored private let searchDelay: Duration
  @ObservationIgnored var onCommand: ((KeyCommand) -> Void)?
  @ObservationIgnored var onPreviewChange: ((Thought?) -> Void)?

  private(set) var entries: [ThoughtEntry] = []
  private(set) var feedback: Feedback?
  private(set) var storageProblem: String? {
    didSet {
      guard storageProblem != oldValue else { return }
      storageFeedback = storageProblem.map { Feedback(kind: .message, text: $0) }
    }
  }
  private var storageFeedback: Feedback?
  @ObservationIgnored private var isPanelShown = false
  private(set) var addedCount = 0
  private(set) var matches: Set<String>?
  private(set) var imageExcerpts: [String: String] = [:]
  var now = Date()
  var selection: [String] = [] {
    didSet {
      guard selection != oldValue else { return }
      if !isRevealing { pendingReveal = [] }
      if isMenuOpen, selection.isEmpty { closeMenu() }
      if isPreviewing, previewThought == nil { isPreviewing = false }
      if isPreviewing { onPreviewChange?(previewThought) }
    }
  }
  private(set) var pendingRemoval: Set<String> = []
  private(set) var pendingDone: [String: Bool] = [:]
  private(set) var isMenuOpen = false
  private(set) var isPreviewing = false {
    didSet {
      if isPreviewing != oldValue { onPreviewChange?(isPreviewing ? previewThought : nil) }
    }
  }
  var menuQuery = "" {
    didSet {
      if menuQuery != oldValue { menuHighlight = 0 }
    }
  }
  var menuHighlight = 0
  private(set) var editing: EditSession?
  var focus: Focus = .input {
    didSet {
      guard focus != oldValue else { return }
      if isPanelShown, !keepsFeedback { endFeedback() }
      if oldValue == .list, focus != .list { isPreviewing = false }
      if oldValue == .edit { commitEditOnLeave() }
    }
  }
  var query = "" {
    didSet {
      guard query != oldValue else { return }
      pendingReveal = []
      scheduleSearch()
    }
  }

  init(
    index: SearchIndex, live: LiveIndex, location: StorageLocation,
    searchDelay: Duration = .milliseconds(80), probe: StorageProbe? = nil,
    mounts: MountSignal = .live,
    feedbackDelay: @escaping @Sendable (Duration) async throws -> Void = {
      try await Task.sleep(for: $0)
    }
  ) {
    self.index = index
    self.live = live
    self.location = location
    self.probe = probe ?? .live(location: location, live: live)
    self.mounts = mounts
    self.searchDelay = searchDelay
    self.feedbackDelay = feedbackDelay
  }

  var editText: String {
    get { editing?.text ?? "" }
    set { editing?.text = newValue }
  }

  var visible: [ThoughtEntry] {
    let shown: [ThoughtEntry]
    if let matches {
      shown = entries.filter { entry in
        guard case .thought(let thought) = entry else { return false }
        return matches.contains(thought.id.rawValue)
      }
    } else {
      shown = entries.filter { !$0.isCleared }
    }
    guard !pendingRemoval.isEmpty else { return shown }
    return shown.filter { !pendingRemoval.contains($0.fileName) }
  }

  func isDone(_ thought: Thought) -> Bool {
    pendingDone[thought.file.lastPathComponent] ?? (thought.done != nil)
  }

  func holdRemoval(of names: Set<String>) {
    pendingRemoval.formUnion(names)
  }

  func releaseRemoval(of names: Set<String>) {
    pendingRemoval.subtract(names)
  }

  func holdDone(_ done: Bool, for names: [String]) {
    for name in names { pendingDone[name] = done }
  }

  func releaseDone(for names: [String]) {
    for name in names { pendingDone[name] = nil }
  }

  private func settlePending() {
    guard !pendingRemoval.isEmpty || !pendingDone.isEmpty else { return }
    var present: [String: Bool] = [:]
    for case .thought(let thought) in entries {
      present[thought.file.lastPathComponent] = thought.done != nil
    }
    pendingRemoval.formIntersection(entries.map(\.fileName))
    pendingDone = pendingDone.filter { name, done in
      guard let actual = present[name] else { return false }
      return actual != done
    }
  }

  var searchTerms: [String] {
    SearchHighlight.terms(in: query)
  }

  var isSearching: Bool {
    !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var selectedEntries: [ThoughtEntry] {
    let chosen = Set(selection)
    return visible.filter { chosen.contains($0.fileName) }
  }

  var menuItems: [ActionItem] {
    ActionCatalog.filter(ActionCatalog.items(for: selectedEntries), by: menuQuery)
  }

  var previewThought: Thought? {
    guard selection.count == 1 else { return nil }
    return selectedEntries.first?.thought
  }

  func expectRestored(_ names: [String]) {
    restored.formUnion(names)
  }

  func reveal(_ names: [String]) {
    guard !names.isEmpty, focus != .edit, focus != .menu else { return }
    pendingReveal = names
    settleReveal()
  }

  private func settleReveal() {
    guard !pendingReveal.isEmpty else { return }
    let shown = visible.map(\.fileName)
    guard pendingReveal.allSatisfy(shown.contains) else { return }
    let wanted = Set(pendingReveal)
    pendingReveal = []
    isRevealing = true
    defer { isRevealing = false }
    if focus != .list { focus = .list }
    selection = shown.filter { wanted.contains($0) }
  }

  func neighbor(excluding names: Set<String>) -> String? {
    let all = visible.map(\.fileName)
    guard let first = all.firstIndex(where: names.contains),
      let last = all.lastIndex(where: names.contains)
    else { return nil }
    if let after = all[(last + 1)...].first(where: { !names.contains($0) }) { return after }
    return all[..<first].last(where: { !names.contains($0) })
  }

  func start() {
    load()
    mounts.observe { [weak self] in
      guard let self else { return }
      Task { await self.retryStorage() }
    }
    do {
      try live.start { [weak self] result in
        Task { @MainActor in self?.receive(result) }
      }
    } catch let error as ThoughtsError {
      report(error)
    } catch {
      tell(error.localizedDescription)
    }
  }

  func load() {
    do {
      entries = try index.entries(includeCleared: true)
      settlePending()
      now = Date()
      refreshMatches()
      settleReveal()
      pruneSelection()
      endEditIfDeleted()
    } catch let error as ThoughtsError {
      report(error)
    } catch {
      tell(error.localizedDescription)
    }
  }

  func apply(_ changes: IndexChanges) {
    guard !changes.isEmpty else { return }
    let held = Set(entries.map(\.fileName))
    load()
    let appeared = Set(entries.map(\.fileName)).subtracting(held)
    let brandNew = appeared.subtracting(restored)
    restored.subtract(appeared)
    if !brandNew.isEmpty { addedCount += 1 }
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

  private func leavesList(by delta: Int) -> Bool {
    let names = visible.map(\.fileName)
    guard let cursor = selection.last.flatMap(names.firstIndex(of:)) else { return false }
    return delta < 0 ? cursor == 0 : cursor == names.count - 1
  }

  func select(_ name: String, extend: Bool) {
    if editing?.name == name { return }
    if let session = editing {
      guard !session.isSaving else { return }
      queuedSelect = (name, extend)
      perform(.saveEdit)
      if editing == nil {
        runQueuedSelect()
      } else if editing?.isSaving != true {
        queuedSelect = nil
      }
      return
    }
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
      guard !visible.isEmpty else { return }
      if focus == .list, leavesList(by: delta) {
        selection = []
        focus = delta < 0 ? .search : .input
        return
      }
      focus = .list
      moveSelection(by: delta, extend: false)
    case .type(let text):
      selection = []
      if query.isEmpty {
        focus = .input
      } else {
        focus = .search
        query += text
        return
      }
    case .extend(let delta):
      moveSelection(by: delta, extend: true)
    case .selectNewest:
      guard let newest = visible.last else { return }
      focus = .list
      selection = [newest.fileName]
    case .focusSearch:
      isPreviewing = false
      focus = .search
    case .clearSearch:
      query = ""
      focus = .input
    case .backToInput:
      if isPreviewing {
        isPreviewing = false
        return
      }
      selection = []
      focus = .input
    case .preview:
      if isPreviewing {
        isPreviewing = false
      } else if previewThought != nil {
        isPreviewing = true
      } else {
        tell(
          selection.isEmpty
            ? String(localized: "Select a thought first")
            : String(localized: "Select one thought to preview"))
      }
      return
    case .actionsMenu:
      isPreviewing = false
      openMenu()
      return
    case .menuMove(let delta):
      let last = menuItems.count - 1
      guard last >= 0 else { return }
      menuHighlight = min(max(menuHighlight + delta, 0), last)
      return
    case .menuClose:
      closeMenu()
      return
    case .menuRun:
      runMenuItem()
      return
    case .edit:
      isPreviewing = false
      beginEdit()
      return
    case .cancelEdit:
      cancelEdit()
      return
    default:
      break
    }
    onCommand?(command)
  }

  private func commitEditOnLeave() {
    guard let session = editing, !session.isSaving else { return }
    perform(.saveEdit)
    if editing != nil, editing?.isSaving != true {
      keepsFeedback = true
      focus = .edit
      keepsFeedback = false
    }
  }

  private func beginEdit() {
    guard selection.count == 1, let entry = selectedEntries.first else {
      tell(
        selection.isEmpty
          ? String(localized: "Select a thought first")
          : String(localized: "Select one thought to edit"))
      return
    }
    guard let thought = entry.thought else {
      tell(String(localized: "That file can't be read, so it can't be edited"))
      return
    }
    let name = thought.file.lastPathComponent
    if let session = editing {
      if session.name == name { focus = .edit }
      return
    }
    let text: String
    let allowsBlank: Bool
    switch thought.content {
    case .text(let value):
      text = value
      allowsBlank = false
    case .image(_, let note):
      text = note
      allowsBlank = true
    }
    editing = EditSession(
      name: name, id: thought.id, file: thought.file, version: thought.version, original: text,
      allowsBlank: allowsBlank, text: text)
    focus = .edit
  }

  private func cancelEdit() {
    guard editing?.isSaving != true else { return }
    editing = nil
    if focus == .edit { focus = .list }
  }

  private func endEdit() {
    editing = nil
    if focus == .edit { focus = .list }
    runQueuedSelect()
  }

  private func runQueuedSelect() {
    guard let next = queuedSelect else { return }
    queuedSelect = nil
    select(next.name, extend: next.extend)
  }

  private func endEditIfDeleted() {
    guard let name = editing?.name, !entries.contains(where: { $0.fileName == name }) else {
      return
    }
    endEdit()
    tell(String(localized: "This thought was deleted."))
  }

  func markEditSaving() {
    editing?.isSaving = true
  }

  func finishEdit(_ outcome: EditOutcome, for name: String) {
    let current = editing?.name == name
    if current { editing?.isSaving = false }
    switch outcome {
    case .saved(let thought):
      replace(thought)
      if current { endEdit() }
    case .changed(let fresh):
      load()
      guard current, editing?.name == name else { return }
      guard let fresh else {
        endEdit()
        tell(String(localized: "That thought changed on disk"))
        return
      }
      replace(fresh)
      editing?.version = fresh.version
      queuedSelect = nil
      focus = .edit
      tell(String(localized: "Changed on disk. Press Enter again to save your text."))
    case .deleted:
      load()
      if current, editing?.name == name { endEdit() }
      tell(String(localized: "This thought was deleted."))
    case .failed(let message):
      if current {
        queuedSelect = nil
        focus = .edit
      }
      tell(message)
    }
  }

  private func replace(_ thought: Thought) {
    guard
      let position = entries.firstIndex(where: { $0.fileName == thought.file.lastPathComponent })
    else { return }
    entries[position] = .thought(thought)
  }

  private func scheduleSearch() {
    searchTask?.cancel()
    searchTask = nil
    guard isSearching, searchDelay > .zero else {
      runSearch()
      return
    }
    searchTask = Task { [weak self, searchDelay] in
      try? await Task.sleep(for: searchDelay)
      guard !Task.isCancelled else { return }
      self?.runSearch()
    }
  }

  private func runSearch() {
    refreshMatches()
    pruneSelection()
  }

  func fieldDidTakeFocus(_ field: Focus) {
    guard !isMenuOpen || field == .menu else { return }
    focus = field
  }

  func closeMenu() {
    guard isMenuOpen else { return }
    isMenuOpen = false
    menuQuery = ""
    focus = .list
  }

  private func openMenu() {
    guard !selection.isEmpty, !selectedEntries.isEmpty else {
      tell(String(localized: "Select a thought first"))
      return
    }
    menuQuery = ""
    menuHighlight = 0
    isMenuOpen = true
    focus = .menu
  }

  private func runMenuItem() {
    let items = menuItems
    let command = items.indices.contains(menuHighlight) ? items[menuHighlight].command : nil
    closeMenu()
    if let command { perform(command) }
  }

  func tell(_ text: String) {
    present(Feedback(kind: .message, text: text))
  }

  func confirm(_ text: String, lingers: Bool = false) {
    guard isPanelShown else { return }
    present(Feedback(kind: .confirmation, text: text, lingers: lingers))
  }

  private func present(_ next: Feedback) {
    feedback = next
    armFeedbackEnd()
  }

  private func endFeedback() {
    feedbackTask?.cancel()
    feedbackTask = nil
    feedback = nil
  }

  func panelDidShow() {
    isPanelShown = true
    armFeedbackEnd()
    if storageProblem != nil { Task { await retryStorage() } }
  }

  var shownFeedback: Feedback? {
    feedback ?? storageFeedback
  }

  func storageRepointed() {
    storageProblem = nil
  }

  func retryStorage() async {
    guard storageProblem != nil, !isRetryingStorage else { return }
    guard let folder = probe.folder(), probe.exists(folder) else { return }
    isRetryingStorage = true
    defer { isRetryingStorage = false }
    let probe = probe
    do {
      try await Task.detached { try probe.restart() }.value
      storageProblem = nil
    } catch let error as ThoughtsError {
      if case .storageUnavailable = error { return }
      tell(Self.message(for: error))
    } catch {
      tell(error.localizedDescription)
    }
  }

  func report(_ error: ThoughtsError) {
    if case .storageUnavailable = error {
      storageProblem = Self.message(for: error)
    } else {
      tell(Self.message(for: error))
    }
  }

  func panelDidHide() {
    isPanelShown = false
    pendingReveal = []
    isPreviewing = false
    isMenuOpen = false
    menuQuery = ""
    feedbackTask?.cancel()
    feedbackTask = nil
    if feedback?.kind == .confirmation { feedback = nil }
  }

  private func armFeedbackEnd() {
    feedbackTask?.cancel()
    feedbackTask = nil
    guard isPanelShown, let current = feedback else { return }
    feedbackTask = Task { [weak self, feedbackDelay] in
      do { try await feedbackDelay(current.lifetime) } catch { return }
      guard let self, self.feedback?.id == current.id else { return }
      self.feedback = nil
    }
  }

  func receive(_ result: Result<IndexChanges, ThoughtsError>) {
    switch result {
    case .success(let changes): apply(changes)
    case .failure(let error): report(error)
    }
  }

  private func refreshMatches() {
    guard isSearching else {
      matches = nil
      imageExcerpts = [:]
      return
    }
    do {
      let ids = try index.search(query)
      matches = Set(ids.map(\.rawValue))
      imageExcerpts = Dictionary(
        uniqueKeysWithValues: try index.imageTextExcerpts(for: ids, query: query).map {
          ($0.key.rawValue, $0.value)
        })
    } catch let error as ThoughtsError {
      matches = []
      imageExcerpts = [:]
      report(error)
    } catch {
      matches = []
      imageExcerpts = [:]
      tell(error.localizedDescription)
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

  nonisolated static func message(for error: ThoughtsError) -> String {
    switch error {
    case .storageUnavailable:
      String(localized: "The thoughts folder isn't available. Choose it in Settings.")
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

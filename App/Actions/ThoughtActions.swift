import Foundation
import ThoughtsCore

@MainActor
final class ThoughtActions {
  private let list: ListModel
  private let location: StorageLocation
  private let pasteboard: PasteboardWriter
  private let opener: SourceOpener
  private let trash: @Sendable (URL) throws -> Void
  private let now: () -> Date
  private(set) var pending: Task<Void, Never>?

  init(
    list: ListModel,
    location: StorageLocation,
    pasteboard: PasteboardWriter,
    opener: SourceOpener = .live,
    trash: @escaping @Sendable (URL) throws -> Void = ThoughtStore.moveToTrash,
    now: @escaping () -> Date = Date.init
  ) {
    self.list = list
    self.location = location
    self.pasteboard = pasteboard
    self.opener = opener
    self.trash = trash
    self.now = now
  }

  func perform(_ command: KeyCommand) {
    switch command {
    case .copy: copy()
    case .copyPath: copyPath()
    case .toggleDone: toggleDone()
    case .delete: delete()
    case .openSource: openSource()
    case .showInFinder: showInFinder()
    default: break
    }
  }

  private func copy() {
    let thoughts = list.selectedEntries.compactMap(\.thought)
    guard !thoughts.isEmpty, let store = makeStore() else { return }
    guard thoughts.count == 1, let only = thoughts.first else {
      pasteboard.write(text: CopyFormat.markdownList(thoughts, store: store))
      return
    }
    switch only.content {
    case .text(let text):
      pasteboard.write(text: text)
    case .image:
      guard let image = store.imageURL(of: only) else { return }
      pasteboard.write(imageAt: image)
    }
  }

  private func copyPath() {
    let entries = list.selectedEntries
    guard !entries.isEmpty, let store = makeStore() else { return }
    let paths = entries.map { entry in
      switch entry {
      case .thought(let thought): CopyFormat.path(of: thought, store: store).path
      case .malformed(let file, _): file.path
      }
    }
    pasteboard.write(text: paths.joined(separator: "\n"))
  }

  private func toggleDone() {
    let thoughts = list.selectedEntries.compactMap(\.thought)
    guard !thoughts.isEmpty else { return }
    let done = thoughts.contains { $0.done == nil }
    let ids = thoughts.map(\.id)
    let date = now()
    run { store in
      for id in ids { _ = try store.setDone(done, for: id, at: date) }
    }
  }

  private func delete() {
    let thoughts = list.selectedEntries.compactMap(\.thought)
    guard !thoughts.isEmpty else { return }
    let ids = thoughts.map(\.id)
    let neighbor = list.neighbor(excluding: Set(thoughts.map { $0.file.lastPathComponent }))
    list.selection = neighbor.map { [$0] } ?? []
    if neighbor == nil { list.focus = .input }
    run { store in try store.delete(ids) }
  }

  private func openSource() {
    let thoughts = list.selectedEntries.compactMap(\.thought)
    guard thoughts.count == 1, let source = thoughts.first?.source,
      SourceOpener.canOpen(source)
    else { return }
    if !opener.open(source) {
      list.showHint(String(localized: "Couldn't open where this came from"))
    }
  }

  private func showInFinder() {
    let entries = list.selectedEntries
    guard !entries.isEmpty, let store = makeStore() else { return }
    let files = entries.map { entry in
      switch entry {
      case .thought(let thought): store.imageURL(of: thought) ?? thought.file
      case .malformed(let file, _): file
      }
    }
    opener.reveal(files)
  }

  private func makeStore() -> ThoughtStore? {
    do {
      return ThoughtStore(folder: try location.resolve(), trash: trash)
    } catch let error as ThoughtsError {
      list.showHint(ListModel.message(for: error))
    } catch {
      list.showHint(error.localizedDescription)
    }
    return nil
  }

  private func run(_ work: @escaping @Sendable (ThoughtStore) throws -> Void) {
    guard let store = makeStore() else { return }
    let previous = pending
    pending = Task { [weak list] in
      await previous?.value
      do {
        try await Task.detached { try work(store) }.value
      } catch let error as ThoughtsError {
        list?.showHint(ListModel.message(for: error))
      } catch {
        list?.showHint(error.localizedDescription)
      }
    }
  }
}

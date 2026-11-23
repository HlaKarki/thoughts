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
    case .saveEdit: saveEdit()
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
    let done = thoughts.contains { !list.isDone($0) }
    let changing = thoughts.filter { list.isDone($0) != done }
    let names = changing.map { $0.file.lastPathComponent }
    let ids = changing.map(\.id)
    let date = now()
    list.holdDone(done, for: names)
    run(
      { store in
        for id in ids { _ = try store.setDone(done, for: id, at: date) }
      },
      rollback: { [list] in list.releaseDone(for: names) })
  }

  private func delete() {
    let thoughts = list.selectedEntries.compactMap(\.thought)
    guard !thoughts.isEmpty else { return }
    let ids = thoughts.map(\.id)
    let names = Set(thoughts.map { $0.file.lastPathComponent })
    let neighbor = list.neighbor(excluding: names)
    list.holdRemoval(of: names)
    list.selection = neighbor.map { [$0] } ?? []
    if neighbor == nil { list.focus = .input }
    run(
      { store in try store.delete(ids) },
      rollback: { [list] in list.releaseRemoval(of: names) })
  }

  private func saveEdit() {
    guard let session = list.editing, !session.isSaving else { return }
    let text = session.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if text == session.original.trimmingCharacters(in: .whitespacesAndNewlines) {
      list.perform(.cancelEdit)
      return
    }
    if text.isEmpty, !session.allowsBlank {
      list.showHint(String(localized: "A thought can't be empty"))
      return
    }
    guard let store = makeStore() else { return }
    list.markEditSaving()
    let previous = pending
    pending = Task { [weak list] in
      await previous?.value
      let outcome = await Task.detached { () -> EditOutcome in
        do {
          return .saved(try store.setText(text, of: session.id, expected: session.version))
        } catch ThoughtsError.changedOnDisk {
          let fresh = try? store.entry(at: session.file).thought
          return .changed(fresh)
        } catch ThoughtsError.deletedOnDisk {
          return .deleted
        } catch let error as ThoughtsError {
          return .failed(ListModel.message(for: error))
        } catch {
          return .failed(error.localizedDescription)
        }
      }.value
      list?.finishEdit(outcome)
    }
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

  private func run(
    _ work: @escaping @Sendable (ThoughtStore) throws -> Void,
    rollback: @escaping @MainActor () -> Void
  ) {
    guard let store = makeStore() else {
      rollback()
      return
    }
    let previous = pending
    pending = Task { [weak list] in
      await previous?.value
      do {
        try await Task.detached { try work(store) }.value
      } catch let error as ThoughtsError {
        rollback()
        list?.showHint(ListModel.message(for: error))
      } catch {
        rollback()
        list?.showHint(error.localizedDescription)
      }
    }
  }
}

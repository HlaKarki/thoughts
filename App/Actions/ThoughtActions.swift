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

  private func selectedThoughts() -> [Thought]? {
    let entries = list.selectedEntries
    guard !entries.isEmpty else {
      list.tell(String(localized: "Select a thought first"))
      return nil
    }
    let thoughts = entries.compactMap(\.thought)
    guard !thoughts.isEmpty else {
      list.tell(String(localized: "That file can't be read, so this doesn't work on it"))
      return nil
    }
    return thoughts
  }

  private func copy() {
    guard let thoughts = selectedThoughts(), let store = makeStore() else { return }
    guard thoughts.count == 1, let only = thoughts.first else {
      pasteboard.write(text: CopyFormat.markdownList(thoughts, store: store))
      list.confirm(String(localized: "Copied"))
      return
    }
    switch only.content {
    case .text(let text):
      pasteboard.write(text: text)
    case .image:
      let image = store.imageURL(of: only)
      switch image.map({ pasteboard.write(imageAt: $0) }) ?? .missing {
      case .written:
        break
      case .missing:
        list.tell(String(localized: "That image file isn't there anymore"))
        return
      case .unreadable:
        list.tell(String(localized: "That image file can't be read"))
        return
      }
    }
    list.confirm(String(localized: "Copied"))
  }

  private func copyPath() {
    let entries = list.selectedEntries
    guard !entries.isEmpty else {
      list.tell(String(localized: "Select a thought first"))
      return
    }
    guard let store = makeStore() else { return }
    let paths = entries.map { entry in
      switch entry {
      case .thought(let thought): CopyFormat.path(of: thought, store: store).path
      case .malformed(let file, _): file.path
      }
    }
    pasteboard.write(text: paths.joined(separator: "\n"))
    list.confirm(
      paths.count == 1
        ? String(localized: "Copied the path") : String(localized: "Copied the paths"))
  }

  private func toggleDone() {
    guard let thoughts = selectedThoughts() else { return }
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
    guard let thoughts = selectedThoughts() else { return }
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
      list.tell(String(localized: "A thought can't be empty"))
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
      list?.finishEdit(outcome, for: session.name)
    }
  }

  private func openSource() {
    guard let thoughts = selectedThoughts() else { return }
    guard thoughts.count == 1, let thought = thoughts.first else {
      list.tell(String(localized: "Select one thought to open its original"))
      return
    }
    guard let source = thought.source, SourceOpener.canOpen(source) else {
      list.tell(String(localized: "This thought has no original to open"))
      return
    }
    if !opener.open(source) {
      list.tell(String(localized: "Couldn't open the original. It may have moved."))
    }
  }

  private func showInFinder() {
    let entries = list.selectedEntries
    guard !entries.isEmpty else {
      list.tell(String(localized: "Select a thought first"))
      return
    }
    guard let store = makeStore() else { return }
    let files = entries.map { entry in
      switch entry {
      case .thought(let thought): store.imageURL(of: thought) ?? thought.file
      case .malformed(let file, _): file
      }
    }
    let present = files.filter { opener.exists($0) }
    guard !present.isEmpty else {
      list.tell(String(localized: "That file isn't there anymore"))
      return
    }
    opener.reveal(present)
    if present.count < files.count {
      list.tell(String(localized: "Some of those files aren't there anymore"))
    }
  }

  private func makeStore() -> ThoughtStore? {
    do {
      return ThoughtStore(folder: try location.resolve(), trash: trash)
    } catch let error as ThoughtsError {
      list.tell(ListModel.message(for: error))
    } catch {
      list.tell(error.localizedDescription)
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
        list?.tell(ListModel.message(for: error))
      } catch {
        rollback()
        list?.tell(error.localizedDescription)
      }
    }
  }
}

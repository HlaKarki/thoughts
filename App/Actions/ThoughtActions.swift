import Foundation
import ThoughtsCore

@MainActor
final class ThoughtActions {
  private static let storeWork = BlockingQueue("thoughts.actions.store")

  let list: ListModel
  private let location: StorageLocation
  private let pasteboard: PasteboardWriter
  private let opener: SourceOpener
  let trash: @Sendable (URL) throws -> URL
  let undoManager: UndoManager
  private let now: () -> Date
  private(set) var pending: Task<Void, Never>?
  private(set) var busy = 0
  var written: [URL: FileVersion] = [:]

  init(
    list: ListModel,
    location: StorageLocation,
    pasteboard: PasteboardWriter,
    opener: SourceOpener = .live,
    trash: @escaping @Sendable (URL) throws -> URL = ThoughtStore.moveToTrash,
    undoManager: UndoManager = UndoManager(),
    now: @escaping () -> Date = Date.init
  ) {
    self.list = list
    self.location = location
    self.pasteboard = pasteboard
    self.opener = opener
    self.trash = trash
    self.undoManager = undoManager
    self.now = now
  }

  func perform(_ command: KeyCommand) {
    switch command {
    case .copy: copy()
    case .copyPath: copyPath()
    case .toggleDone: toggleDone()
    case .delete: delete()
    case .clearDone: clearDone()
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
      list.tell(String(localized: "That file can't be read"))
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
      list.confirm(String(localized: "Copied"))
    case .image:
      guard let image = store.imageURL(of: only) else {
        list.tell(String(localized: "That image file isn't there anymore"))
        return
      }
      let claim = pasteboard.claim()
      enqueue { [pasteboard, weak list] in
        switch await pasteboard.write(imageAt: image, claim: claim) {
        case .written:
          list?.confirm(String(localized: "Copied"))
        case .superseded:
          break
        case .missing:
          list?.tell(String(localized: "That image file isn't there anymore"))
        case .unreadable:
          list?.tell(String(localized: "That image file can't be read"))
        }
      }
    }
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
    let date = now()
    list.holdDone(done, for: names)
    run(
      { store in
        var reversals: [Reversal] = []
        var failure: (any Error)?
        for thought in changing {
          do {
            let before = (try? store.entry(at: thought.file).thought) ?? thought
            let after = try store.setDone(done, for: thought.id, at: date)
            reversals.append(Reversal(before: before, after: after))
          } catch {
            failure = error
            break
          }
        }
        return Attempt(value: reversals.isEmpty ? nil : reversals, failure: failure)
      },
      rollback: { [list] landed in
        let kept = Set((landed ?? []).map { $0.file.lastPathComponent })
        list.releaseDone(for: names.filter { !kept.contains($0) })
      },
      finish: { [self] reversals in record(.amend(reversals)) })
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
      { store in
        var landed: [TrashedFile] = []
        do {
          try store.delete(ids, landing: &landed)
          return Attempt(value: landed.isEmpty ? nil : landed)
        } catch {
          return Attempt(value: landed.isEmpty ? nil : landed, failure: error)
        }
      },
      rollback: { [list] landed in
        let gone = Set((landed ?? []).map { $0.original.lastPathComponent })
        list.releaseRemoval(of: names.subtracting(gone))
      },
      finish: { [self] files in
        record(.restore(files))
        let count = files.filter { Self.isThoughtFile($0.original) }.count
        list.confirm(
          count == 1
            ? String(localized: "Moved to the Trash. Press ⌘Z to put it back.")
            : String(localized: "Moved \(count) thoughts to the Trash. Press ⌘Z to put them back."),
          lingers: true)
      })
  }

  private func clearDone() {
    let store: ThoughtStore
    do {
      store = ThoughtStore(folder: try location.resolve(), trash: trash)
    } catch let error as ThoughtsError {
      list.report(error)
      return
    } catch {
      list.tell(error.localizedDescription)
      return
    }
    run(
      { store in
        var cleared: [Thought] = []
        do {
          try store.clearingDone(landing: &cleared)
          return Attempt(value: cleared.isEmpty ? nil : cleared)
        } catch {
          return Attempt(value: cleared.isEmpty ? nil : cleared, failure: error)
        }
      },
      store: store,
      emptyNote: String(localized: "Nothing is marked done"),
      rollback: { _ in },
      fail: { [list] error in
        if let error = error as? ThoughtsError {
          list.report(error)
        } else {
          list.tell(error.localizedDescription)
        }
      },
      finish: { [self] cleared in
        record(.amend(cleared.map(Reversal.cleared)))
        list.confirm(
          String(localized: "Cleared the done thoughts. Press ⌘Z to bring them back."),
          lingers: true)
      })
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
    enqueue { [self, weak list] in
      let outcome = await Self.storeWork.run { () -> EditOutcome in
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
      }
      if case .saved(let saved) = outcome {
        record(
          .amend([
            Reversal(
              id: session.id, file: session.file, version: saved.version,
              applied: .text(text), previous: .text(session.original))
          ]))
      }
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

  func enqueue(_ body: @escaping @MainActor () async -> Void) {
    let previous = pending
    busy += 1
    pending = Task { [weak self] in
      await previous?.value
      await body()
      self?.busy -= 1
    }
  }

  func makeStore() -> ThoughtStore? {
    do {
      return ThoughtStore(folder: try location.resolve(), trash: trash)
    } catch let error as ThoughtsError {
      list.tell(ListModel.message(for: error))
    } catch {
      list.tell(error.localizedDescription)
    }
    return nil
  }

  private func run<T: Sendable>(
    _ work: @escaping @Sendable (ThoughtStore) throws -> Attempt<T>,
    store given: ThoughtStore? = nil,
    emptyNote: String? = nil,
    rollback: @escaping @MainActor (T?) -> Void,
    fail: (@MainActor (any Error) -> Void)? = nil,
    finish: @escaping @MainActor (T) -> Void
  ) {
    guard let store = given ?? makeStore() else {
      rollback(nil)
      return
    }
    enqueue { [weak list] in
      let attempt: Attempt<T>
      do {
        attempt = try await Self.storeWork.run { try work(store) }
      } catch {
        attempt = Attempt(failure: error)
      }
      if let value = attempt.value {
        finish(value)
      } else if attempt.failure == nil, let emptyNote {
        list?.tell(emptyNote)
      }
      guard let failure = attempt.failure else { return }
      rollback(attempt.value)
      if let fail {
        fail(failure)
      } else if let error = failure as? ThoughtsError {
        list?.tell(ListModel.message(for: error))
      } else {
        list?.tell(failure.localizedDescription)
      }
    }
  }
}

struct Attempt<T: Sendable>: Sendable {
  var value: T?
  var failure: (any Error)?

  init(value: T?, failure: (any Error)? = nil) {
    self.value = value
    self.failure = failure
  }

  init(failure: any Error) {
    self.failure = failure
  }
}

import Foundation
import ThoughtsCore

struct Reversal: Sendable, Equatable {
  let id: ThoughtID
  let file: URL
  let version: FileVersion
  let restore: ThoughtChange
  let current: ThoughtChange

  init(
    id: ThoughtID, file: URL, version: FileVersion, applied: ThoughtChange, previous: ThoughtChange
  ) {
    self.id = id
    self.file = file
    self.version = version
    self.restore = previous
    self.current = applied
  }

  init(before: Thought, after: Thought) {
    self.init(
      id: after.id, file: after.file, version: after.version, applied: .mark(after.mark),
      previous: .mark(before.mark))
  }

  static func cleared(_ thought: Thought) -> Reversal {
    Reversal(
      id: thought.id, file: thought.file, version: thought.version, applied: .mark(thought.mark),
      previous: .mark(ThoughtMark(done: thought.done, cleared: false)))
  }

  var amendment: Amendment {
    Amendment(id: id, file: file, expected: version, change: restore)
  }

  func flipped(at version: FileVersion) -> Reversal {
    Reversal(id: id, file: file, version: version, applied: restore, previous: current)
  }
}

enum HistoryStep: Sendable {
  case restore([TrashedFile])
  case trash([URL])
  case amend([Reversal])
}

enum HistoryDirection {
  case undo
  case redo
}

extension ThoughtActions {
  static func isThoughtFile(_ url: URL) -> Bool {
    url.pathExtension.lowercased() == "md"
  }

  func record(_ step: HistoryStep) {
    if case .amend(let reversals) = step {
      for reversal in reversals { written[reversal.file] = reversal.version }
    }
    let grouping = !undoManager.isUndoing && !undoManager.isRedoing
    if grouping { undoManager.beginUndoGrouping() }
    undoManager.registerUndo(withTarget: self) { target in
      MainActor.assumeIsolated { target.apply(step) }
    }
    if grouping { undoManager.endUndoGrouping() }
  }

  func nothingToDo(_ direction: HistoryDirection) {
    tellNothing(direction)
  }

  func deferIfBusy(_ direction: HistoryDirection) -> Bool {
    guard busy > 0 else { return false }
    enqueue { [self] in
      switch direction {
      case .undo where undoManager.canUndo: undoManager.undo()
      case .redo where undoManager.canRedo: undoManager.redo()
      default: tellNothing(direction)
      }
    }
    return true
  }

  private func tellNothing(_ direction: HistoryDirection) {
    list.tell(
      direction == .undo
        ? String(localized: "Nothing to undo") : String(localized: "Nothing to redo"))
  }

  private func apply(_ step: HistoryStep) {
    guard let store = makeStore() else { return }
    do {
      switch step {
      case .restore(let files):
        try store.restore(files)
        record(.trash(files.map(\.original)))
        let names = files.map(\.original).filter(Self.isThoughtFile).map(\.lastPathComponent)
        list.releaseRemoval(of: Set(names))
        list.expectRestored(names)
        list.reveal(names)
      case .trash(let originals):
        let names = Set(originals.filter(Self.isThoughtFile).map(\.lastPathComponent))
        let neighbor = list.neighbor(excluding: names)
        list.holdRemoval(of: names)
        let moved: [TrashedFile]
        do {
          moved = try store.trashFiles(originals)
        } catch {
          list.releaseRemoval(of: names)
          throw error
        }
        record(.restore(moved))
        list.selection = neighbor.map { [$0] } ?? []
        if neighbor == nil { list.focus = .input }
      case .amend(let reversals):
        let current = reversals.map { reversal in
          Reversal(
            id: reversal.id, file: reversal.file,
            version: written[reversal.file] ?? reversal.version,
            applied: reversal.current, previous: reversal.restore)
        }
        let applied = try store.amend(current.map(\.amendment))
        for (reversal, thought) in zip(reversals, applied) {
          if case .mark(let mark) = reversal.restore {
            list.holdDone(mark.done != nil, for: [thought.file.lastPathComponent])
          }
        }
        record(.amend(zip(current, applied).map { $0.flipped(at: $1.version) }))
        list.reveal(applied.map { $0.file.lastPathComponent })
      }
    } catch {
      list.tell(Self.reason(for: error))
    }
  }

  static func reason(for error: any Error) -> String {
    switch error {
    case RestoreError.notInTrash:
      String(localized: "Couldn't put it back. It's no longer in the Trash.")
    case RestoreError.nameTaken:
      String(localized: "Couldn't put it back. A file with that name is already in the folder.")
    case RestoreError.changed, ThoughtsError.changedOnDisk(_), ThoughtsError.deletedOnDisk(_):
      String(localized: "Couldn't undo. The thought changed since then.")
    case let error as ThoughtsError:
      ListModel.message(for: error)
    default:
      error.localizedDescription
    }
  }
}

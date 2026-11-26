import AppKit
import ThoughtsCore

struct PasteboardRead: @unchecked Sendable {
  enum Checked<Value: Sendable>: Sendable {
    case read(Value)
    case skipped
  }

  private static let queue = BlockingQueue("thoughts.pasteboard-read", concurrent: true)

  let pasteboard: NSPasteboard

  func run<T: Sendable>(_ read: @escaping @Sendable (NSPasteboard) -> T) async -> T {
    await Self.queue.run { [self] in read(pasteboard) }
  }

  func run<T: Sendable>(
    expecting changeCount: Int,
    unless excluded: @escaping @Sendable ([String]) -> Bool = ClipboardTypes.isExcluded,
    _ read: @escaping @Sendable (NSPasteboard) -> T
  ) async -> Checked<T> {
    await run { board in
      guard Self.holds(changeCount, in: board, unless: excluded) else { return .skipped }
      let value = read(board)
      guard Self.holds(changeCount, in: board, unless: excluded) else { return .skipped }
      return .read(value)
    }
  }

  private static func holds(
    _ changeCount: Int, in board: NSPasteboard, unless excluded: ([String]) -> Bool
  ) -> Bool {
    board.changeCount == changeCount && !excluded((board.types ?? []).map(\.rawValue))
  }
}

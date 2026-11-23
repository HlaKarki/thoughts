import Foundation
import ThoughtsCore

struct StorageMover: Sendable {
  var current: @Sendable () throws -> URL
  var exists: @Sendable (URL) -> Bool
  var stop: @Sendable () -> Void
  var apply: @Sendable (URL) throws -> Void
  var point: @Sendable (URL) throws -> Void
  var relocate: @Sendable (URL) throws -> Void
  var restart: @Sendable () throws -> Void

  static func moving(location: StorageLocation, index: SearchIndex, live: LiveIndex) -> Self {
    Self(location: location, index: index, live: live) { try location.move(to: $0) }
  }

  static func choosing(location: StorageLocation, index: SearchIndex, live: LiveIndex) -> Self {
    Self(location: location, index: index, live: live) { try location.setFolder($0) }
  }

  private init(
    location: StorageLocation, index: SearchIndex, live: LiveIndex,
    apply: @escaping @Sendable (URL) throws -> Void
  ) {
    self.init(
      current: { try location.configuredFolder() },
      stop: { live.stop() },
      apply: apply,
      relocate: { try index.relocate(to: $0) },
      restart: { try live.restart() },
      exists: { FileManager.default.fileExists(atPath: $0.path) },
      point: { try location.setFolder($0) })
  }

  init(
    current: @escaping @Sendable () throws -> URL,
    stop: @escaping @Sendable () -> Void,
    apply: @escaping @Sendable (URL) throws -> Void,
    relocate: @escaping @Sendable (URL) throws -> Void,
    restart: @escaping @Sendable () throws -> Void,
    exists: @escaping @Sendable (URL) -> Bool = { _ in true },
    point: (@Sendable (URL) throws -> Void)? = nil
  ) {
    self.current = current
    self.exists = exists
    self.stop = stop
    self.apply = apply
    self.point = point ?? apply
    self.relocate = relocate
    self.restart = restart
  }

  func run(to destination: URL) throws -> URL {
    let before = try current()
    let missing = !exists(before)
    stop()
    var failure: Error?
    do {
      try (missing ? point : apply)(destination)
    } catch {
      failure = error
    }
    let after = (try? current()) ?? before
    if after.standardized.path != before.standardized.path {
      do {
        try relocate(after)
      } catch {
        failure = failure ?? error
      }
    }
    if exists(after) {
      do {
        try restart()
      } catch {
        failure = failure ?? error
      }
    }
    if let failure { throw failure }
    return after
  }

  func perform(to destination: URL) async throws -> URL {
    try await Task.detached { try self.run(to: destination) }.value
  }

  static func message(for error: Error) -> String {
    switch error {
    case ThoughtsError.folderNotEmpty(let names):
      let shown = names.prefix(5).joined(separator: ", ")
      let more = names.count > 5 ? String(localized: " and \(names.count - 5) more") : ""
      return String(localized: "These files are in the way: \(shown)\(more)")
    case let error as ThoughtsError:
      return ListModel.message(for: error)
    default:
      return error.localizedDescription
    }
  }
}

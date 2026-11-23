import Foundation
import ThoughtsCore

struct StorageMover: Sendable {
  var resolve: @Sendable () throws -> URL
  var stop: @Sendable () -> Void
  var apply: @Sendable (URL) throws -> Void
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
      resolve: { try location.resolve() },
      stop: { live.stop() },
      apply: apply,
      relocate: { try index.relocate(to: $0) },
      restart: { try live.restart() })
  }

  init(
    resolve: @escaping @Sendable () throws -> URL,
    stop: @escaping @Sendable () -> Void,
    apply: @escaping @Sendable (URL) throws -> Void,
    relocate: @escaping @Sendable (URL) throws -> Void,
    restart: @escaping @Sendable () throws -> Void
  ) {
    self.resolve = resolve
    self.stop = stop
    self.apply = apply
    self.relocate = relocate
    self.restart = restart
  }

  func run(to destination: URL) throws -> URL {
    let before = try resolve()
    stop()
    var failure: Error?
    do {
      try apply(destination)
    } catch {
      failure = error
    }
    let after = (try? resolve()) ?? before
    if after.standardized.path != before.standardized.path {
      do {
        try relocate(after)
      } catch {
        failure = failure ?? error
      }
    }
    do {
      try restart()
    } catch {
      failure = failure ?? error
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

import AppKit
import Testing

final class Throwaway: @unchecked Sendable {
  struct Unscoped: Error {}

  @TaskLocal static var current: Throwaway?

  static let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("thoughts.tests.defaults", isDirectory: true)

  let folder = Throwaway.root.appendingPathComponent(UUID().uuidString, isDirectory: true)
  private let lock = NSLock()
  private var domains: [(name: String, defaults: UserDefaults)] = []
  private var boards: [NSPasteboard] = []

  static func suite(sourceLocation: SourceLocation = #_sourceLocation) throws -> (
    name: String, defaults: UserDefaults
  ) {
    guard let scope = scope(sourceLocation) else { throw Unscoped() }
    return try scope.suite(sourceLocation: sourceLocation)
  }

  static func defaults(sourceLocation: SourceLocation = #_sourceLocation) throws -> UserDefaults {
    try suite(sourceLocation: sourceLocation).defaults
  }

  static func pasteboard(sourceLocation: SourceLocation = #_sourceLocation) -> NSPasteboard {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    scope(sourceLocation)?.keep(board)
    return board
  }

  private static func scope(_ sourceLocation: SourceLocation) -> Throwaway? {
    if current == nil {
      Issue.record(
        "A test made a throwaway outside a suite marked .throwaway", sourceLocation: sourceLocation)
    }
    return current
  }

  private func suite(sourceLocation: SourceLocation) throws -> (
    name: String, defaults: UserDefaults
  ) {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let name = folder.appendingPathComponent("thoughts.tests.\(UUID().uuidString)").path
    let defaults = try #require(UserDefaults(suiteName: name), sourceLocation: sourceLocation)
    lock.withLock { domains.append((name, defaults)) }
    return (name, defaults)
  }

  private func keep(_ board: NSPasteboard) {
    lock.withLock { boards.append(board) }
  }

  func throwAway() {
    let (domains, boards) = lock.withLock { (self.domains, self.boards) }
    for (name, defaults) in domains {
      defaults.removePersistentDomain(forName: name)
    }
    try? FileManager.default.removeItem(at: folder)
    for board in boards {
      board.releaseGlobally()
    }
  }
}

struct ThrowawayTrait: SuiteTrait, TestTrait, TestScoping {
  var isRecursive: Bool { true }

  func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
    testCase == nil ? nil : self
  }

  func provideScope(
    for test: Test, testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
    let scope = Throwaway()
    defer { scope.throwAway() }
    try await Throwaway.$current.withValue(scope) { try await function() }
  }
}

extension Trait where Self == ThrowawayTrait {
  static var throwaway: Self { Self() }
}

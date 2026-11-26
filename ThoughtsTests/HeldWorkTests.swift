import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

final class Stamp: @unchecked Sendable {
  private let lock = NSLock()
  private var at: ContinuousClock.Instant?

  var value: ContinuousClock.Instant? { lock.withLock { at } }

  func mark() {
    lock.withLock { at = .now }
  }
}

@MainActor
@Suite(.serialized, .throwaway)
struct HeldWorkTests {
  static let count = ProcessInfo.processInfo.activeProcessorCount + 2

  static func expectRoom(
    whileHolding hold: Hold, since start: ContinuousClock.Instant,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async {
    for _ in 0..<50 { await Task.yield() }
    let other = Stamp()
    Task.detached { other.mark() }
    await hold.waitForArrivals(count)
    for _ in 0..<250 where other.value == nil {
      try? await Task.sleep(for: .milliseconds(20))
    }
    let started = hold.arrival(count).map { $0 - start }
    let ran = other.value.map { $0 - start }
    hold.release()
    #expect(
      started.map { $0 < .seconds(1) } == true,
      "the last of \(count) held reads started after \(String(describing: started))",
      sourceLocation: sourceLocation)
    #expect(
      ran.map { $0 < .seconds(1) } == true,
      "other async work waited \(String(describing: ran)) behind the held reads",
      sourceLocation: sourceLocation)
  }

  @Test func heldClipboardReadsLeaveRoomForOtherWork() async {
    let hold = Hold()
    defer { hold.release() }
    let board = PasteboardSnapshotTests.privateBoard()
    let read = PasteboardRead(pasteboard: board)
    let start = ContinuousClock.now
    let reads = (0..<Self.count).map { _ in Task { await read.run { _ in hold.pass() } } }
    await Self.expectRoom(whileHolding: hold, since: start)
    for task in reads { await task.value }
  }

  @Test func heldFirstRunFolderReadsLeaveRoomForOtherWork() async throws {
    let hold = Hold()
    defer { hold.release() }
    let models = try (0..<Self.count).map { _ in
      let system = FakeSystem()
      system.folderReads.holdEachRead(with: hold)
      return try SettingsFixtures.firstRun(
        system: system, preferences: SettingsFixtures.preferences())
    }
    let start = ContinuousClock.now
    let reads = models.map { model in Task { await model.readWatchedFolders() } }
    await Self.expectRoom(whileHolding: hold, since: start)
    for task in reads { await task.value }
  }

  @Test func heldScreenshotFolderListingsLeaveRoomForOtherWork() async throws {
    let hold = Hold()
    defer { hold.release() }
    let temp = TempFolder()
    let watchers = (0..<Self.count).map { _ in
      ScreenshotFolderWatcher(
        storageFolder: { nil },
        listFolder: { _ in
          hold.pass()
          return []
        })
    }
    defer { for watcher in watchers { watcher.stop() } }
    let start = ContinuousClock.now
    for watcher in watchers { watcher.update(folders: [temp.url]) }
    await Self.expectRoom(whileHolding: hold, since: start)
    for watcher in watchers { await watcher.caughtUp() }
  }

  @Test func heldStorageChecksLeaveRoomForOtherWork() async throws {
    let hold = Hold()
    defer { hold.release() }
    let probe = StorageProbe(
      folder: { URL(fileURLWithPath: "/example/home/Thoughts", isDirectory: true) },
      exists: { _ in
        hold.pass()
        return true
      },
      restart: {})
    let fixtures = try (0..<Self.count).map { _ in try ListFixture(probe: probe) }
    let start = ContinuousClock.now
    let checks = fixtures.map { fixture in Task { await fixture.model.checkStorage() } }
    await Self.expectRoom(whileHolding: hold, since: start)
    for task in checks { await task.value }
  }
}

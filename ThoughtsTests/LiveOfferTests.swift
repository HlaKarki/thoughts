import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized)
struct LiveOfferTests {
  static func withOffer(_ rig: OfferCenterTests.Rig) async throws {
    rig.center.start()
    rig.center.receive(.file(try OfferCenterTests.writeShot(in: rig.temp), at: Date()))
    #expect(await PanelHarness.waitUntil { rig.center.current != nil }, "no offer appeared")
  }

  @Test func turningOffersOffTakesTheOfferThatIsUp() async throws {
    let rig = try OfferCenterTests.rig()
    defer {
      rig.center.stop()
      rig.board.releaseGlobally()
    }
    try await Self.withOffer(rig)
    rig.preferences.offersEnabled = false
    #expect(await PanelHarness.waitUntil { rig.center.current == nil }, "the offer stayed up")
    #expect(rig.plays.changes.last.map { $0 == nil } == true)
    await #expect(throws: ThoughtsError.self) { _ = try await rig.center.accept() }
  }

  @Test func changingTheCaptureKeyUpdatesTheOfferThatIsUp() async throws {
    let rig = try OfferCenterTests.rig()
    defer {
      rig.center.stop()
      rig.board.releaseGlobally()
    }
    try await Self.withOffer(rig)
    let before = rig.plays.changes.count
    let id = rig.center.current?.id
    rig.preferences.captureMethod = .shortcut
    #expect(
      await PanelHarness.waitUntil { rig.plays.changes.count == before + 1 },
      "the chip was not told about the new key")
    #expect(rig.plays.changes.last??.id == id)
    #expect(rig.center.current?.id == id)
  }

  @Test func reRecordingTheCaptureShortcutUpdatesTheOfferThatIsUp() async throws {
    let notifications = NotificationCenter()
    let rig = try OfferCenterTests.rig(notifications: notifications)
    defer {
      rig.center.stop()
      rig.board.releaseGlobally()
    }
    rig.preferences.captureMethod = .shortcut
    try await Self.withOffer(rig)
    let before = rig.plays.changes.count
    let id = rig.center.current?.id
    notifications.post(name: .captureShortcutChanged, object: nil)
    #expect(
      await PanelHarness.waitUntil { rig.plays.changes.count == before + 1 },
      "the chip was not told about the new shortcut")
    #expect(rig.plays.changes.last??.id == id)
    #expect(rig.center.current?.id == id)
  }

  @Test func aShortcutChangeLeavesAnOfferAloneWhenTheGestureIsTheMethod() async throws {
    let notifications = NotificationCenter()
    let rig = try OfferCenterTests.rig(notifications: notifications)
    defer {
      rig.center.stop()
      rig.board.releaseGlobally()
    }
    rig.preferences.captureMethod = .doubleTap(.shift)
    try await Self.withOffer(rig)
    let before = rig.plays.changes.count
    notifications.post(name: .captureShortcutChanged, object: nil)
    try? await Task.sleep(for: .milliseconds(300))
    #expect(rig.plays.changes.count == before)
  }

  @Test func aShortcutChangeAfterStopDoesNothing() async throws {
    let notifications = NotificationCenter()
    let rig = try OfferCenterTests.rig(notifications: notifications)
    defer { rig.board.releaseGlobally() }
    rig.preferences.captureMethod = .shortcut
    try await Self.withOffer(rig)
    rig.center.stop()
    let before = rig.plays.changes.count
    notifications.post(name: .captureShortcutChanged, object: nil)
    try? await Task.sleep(for: .milliseconds(300))
    #expect(rig.plays.changes.count == before)
  }

  @Test func movingTheStorageFolderUpdatesWhatIsWatched() async throws {
    let rig = try OfferCenterTests.rig()
    defer { rig.board.releaseGlobally() }
    let moved = rig.temp.url.appendingPathComponent("Moved", isDirectory: true)
    try FileManager.default.createDirectory(at: moved, withIntermediateDirectories: true)
    let storage = Box(url: rig.fixture.folder)
    let watcher = ScreenshotFolderWatcher(storageFolder: { storage.url })
    let center = OfferCenter(
      preferences: rig.preferences, input: rig.fixture.input,
      clipboard: ClipboardWatcher(pasteboard: rig.board, accessBehavior: { .ask }),
      screenshots: watcher, sound: SavedSound(preferences: rig.preferences, player: {}),
      source: { nil }, pasteboard: rig.board,
      location: ScreenshotLocation(defaults: nil, home: rig.temp.url),
      accessBehavior: { .ask })
    rig.preferences.watchedFolders = [moved]
    center.start()
    defer { center.stop() }
    func watches() -> Bool {
      watcher.watchedFolders.contains {
        ScreenshotFolderWatcher.key($0) == ScreenshotFolderWatcher.key(moved)
      }
    }
    #expect(watches())
    storage.url = moved
    center.storageRepointed()
    #expect(!watches())
    storage.url = rig.fixture.folder
    center.storageRepointed()
    #expect(watches())
  }

  final class Box: @unchecked Sendable {
    var url: URL

    init(url: URL) {
      self.url = url
    }
  }
}

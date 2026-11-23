import AppKit
import Foundation
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

final class Flag: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: Bool

  init(_ value: Bool) {
    stored = value
  }

  var value: Bool {
    get { lock.withLock { stored } }
    set { lock.withLock { stored = newValue } }
  }
}

@MainActor
struct OfferGateTests {
  @MainActor
  final class Reads {
    var paths: [String] = []
  }

  static func rig(firstRunDone: Bool) throws -> (OfferCenter, OfferGate, Reads, Preferences) {
    let name = "thoughts.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    let preferences = Preferences(defaults: defaults)
    preferences.firstRunDone = firstRunDone
    let reads = Reads()
    let temp = TempFolder()
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    let input = InputModel(
      location: StorageLocation(
        appName: "ThoughtsTests", environment: ["THOUGHTS_DIR": temp.url.path], home: temp.url),
      onFailure: { _ in })
    let center = OfferCenter(
      preferences: preferences, input: input,
      clipboard: ClipboardWatcher(pasteboard: board, accessBehavior: { .alwaysAllow }),
      screenshots: ScreenshotFolderWatcher(
        storageFolder: { nil },
        listFolder: {
          reads.paths.append($0.path)
          return []
        }),
      sound: SavedSound(preferences: preferences, player: {}),
      source: { nil }, pasteboard: board,
      location: ScreenshotLocation(defaults: nil, home: temp.url),
      accessBehavior: { .alwaysAllow })
    let gate = OfferGate(firstRunDone: { preferences.firstRunDone }, start: { center.start() })
    return (center, gate, reads, preferences)
  }

  @Test func aFirstLaunchReadsNoFolderUntilFirstRunFinishes() throws {
    let (center, gate, reads, preferences) = try Self.rig(firstRunDone: false)
    defer { center.stop() }
    gate.launch()
    #expect(reads.paths.isEmpty)
    #expect(center.current == nil)
    preferences.firstRunDone = true
    gate.firstRunFinished()
    #expect(!reads.paths.isEmpty)
  }

  @Test func aNormalLaunchStartsOffersAtOnce() throws {
    let (center, gate, reads, _) = try Self.rig(firstRunDone: true)
    defer { center.stop() }
    gate.launch()
    #expect(!reads.paths.isEmpty)
  }
}

struct StorageRepointTests {
  static let picked = URL(fileURLWithPath: "/example/home/Renamed", isDirectory: true)
  static let gone = URL(fileURLWithPath: "/example/home/Thoughts", isDirectory: true)

  @Test func aMissingFolderIsRepointedWithoutMovingAnything() throws {
    let log = CallLog()
    let state = StorageMoverTests.Folder(Self.gone)
    let mover = StorageMover(
      current: { state.url },
      stop: { log.add("stop") },
      apply: { log.add("move \($0.path)") },
      relocate: { log.add("relocate \($0.path)") },
      restart: { log.add("restart") },
      exists: { $0.path == Self.picked.path },
      point: {
        log.add("point \($0.path)")
        state.url = $0
      })
    #expect(try mover.run(to: Self.picked) == Self.picked)
    #expect(
      log.events == [
        "stop", "point /example/home/Renamed", "relocate /example/home/Renamed", "restart",
      ])
  }

  @Test func aMissingFolderThatCannotBeRepointedIsNotRestarted() throws {
    let log = CallLog()
    let mover = StorageMover(
      current: { Self.gone },
      stop: { log.add("stop") },
      apply: { log.add("move \($0.path)") },
      relocate: { log.add("relocate \($0.path)") },
      restart: { log.add("restart") },
      exists: { _ in false },
      point: { _ in throw ThoughtsError.io("no") })
    #expect(throws: ThoughtsError.io("no")) { try mover.run(to: Self.picked) }
    #expect(log.events == ["stop"])
  }

  @Test func aRealMissingFolderIsRepointedAndNeverRecreated() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ThoughtsRepointTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let location = StorageLocation(appName: "ThoughtsTests", environment: [:], home: root)
    let old = root.appendingPathComponent("Thoughts", isDirectory: true)
    try location.setFolder(old)
    let renamed = root.appendingPathComponent("Renamed", isDirectory: true)
    try FileManager.default.createDirectory(at: renamed, withIntermediateDirectories: true)
    try Data("a".utf8).write(to: renamed.appendingPathComponent("20260101-000000-a.md"))
    try Data("b".utf8).write(to: renamed.appendingPathComponent("notes.txt"))
    let log = CallLog()
    let mover = StorageMover(
      current: { try location.configuredFolder() },
      stop: { log.add("stop") },
      apply: { try location.move(to: $0) },
      relocate: { log.add("relocate \($0.lastPathComponent)") },
      restart: { log.add("restart") },
      exists: { FileManager.default.fileExists(atPath: $0.path) },
      point: { try location.setFolder($0) })
    #expect(try mover.run(to: renamed).lastPathComponent == "Renamed")
    #expect(log.events == ["stop", "relocate Renamed", "restart"])
    #expect(!FileManager.default.fileExists(atPath: old.path))
    #expect(try location.configuredFolder().lastPathComponent == "Renamed")
  }
}

@MainActor
struct SettingsStorageRowTests {
  @Test func aMissingFolderIsShownAsMissingUntilItIsRepointed() async throws {
    let present = Flag(false)
    let log = CallLog()
    let system = FakeSystem()
    let target = SettingsFixtures.home.appendingPathComponent("Found", isDirectory: true)
    system.picks = [target]
    let mover = StorageMover(
      current: { SettingsFixtures.home.appendingPathComponent("Thoughts", isDirectory: true) },
      stop: {},
      apply: { _ in },
      relocate: { _ in },
      restart: { log.add("restart") },
      exists: { _ in present.value },
      point: { _ in present.value = true })
    let model = try SettingsFixtures.settings(
      system: system, preferences: SettingsFixtures.preferences(), mover: mover)
    var repointed = 0
    model.onStorageRepointed = { repointed += 1 }
    #expect(model.storageMissing)
    await model.moveStorage()
    #expect(!model.storageMissing)
    #expect(repointed == 1)
    #expect(log.events == ["restart"])
  }

  @Test func refreshSeesTheFolderComeBackWithoutCreatingIt() throws {
    let present = Flag(false)
    let log = CallLog()
    let mover = SettingsFixtures.mover(log: log, exists: { _ in present.value })
    let model = try SettingsFixtures.settings(
      system: FakeSystem(), preferences: SettingsFixtures.preferences(), mover: mover)
    #expect(model.storageMissing)
    present.value = true
    model.refresh()
    #expect(!model.storageMissing)
    #expect(log.events.isEmpty)
  }

  @Test func theMissingNoteDoesNotChangeTheRowHeight() throws {
    func height(missing: Bool) throws -> CGFloat {
      let mover = SettingsFixtures.mover(exists: { _ in !missing })
      let model = try SettingsFixtures.settings(
        system: FakeSystem(), preferences: SettingsFixtures.preferences(), mover: mover)
      let host = NSHostingView(rootView: StorageSection(model: model).frame(width: 476))
      return host.fittingSize.height
    }
    #expect(try height(missing: true) == height(missing: false))
  }
}

@MainActor
struct StorageProblemTests {
  struct Rig {
    let fixture: ListFixture
    let log: CallLog
    let present: Flag
    let mounts: MountBox
  }

  @MainActor
  final class MountBox {
    var fire: @MainActor () -> Void = {}
  }

  static func rig() throws -> Rig {
    let log = CallLog()
    let present = Flag(false)
    let box = MountBox()
    let probe = StorageProbe(
      folder: { URL(fileURLWithPath: "/example/home/Thoughts", isDirectory: true) },
      exists: { _ in present.value },
      restart: { log.add("restart") })
    let fixture = try ListFixture(
      probe: probe, mounts: MountSignal { handler in box.fire = handler })
    fixture.model.receive(.failure(.storageUnavailable("/example/home/Thoughts")))
    return Rig(fixture: fixture, log: log, present: present, mounts: box)
  }

  static let message =
    "The thoughts folder isn't available. Choose it in Settings."

  @Test func aStorageFailureStaysUntilItClears() throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    #expect(model.storageProblem == Self.message)
    #expect(model.shownFeedback?.text == Self.message)
    #expect(model.feedback == nil)
    model.panelDidShow()
    model.panelDidHide()
    #expect(model.shownFeedback?.text == Self.message)
    model.storageRepointed()
    #expect(model.shownFeedback == nil)
  }

  @Test func theStorageProblemKeepsOneIdentityUntilItChanges() throws {
    let rig = try Self.rig()
    let model = rig.fixture.model
    let first = try #require(model.shownFeedback)
    #expect(model.shownFeedback?.id == first.id)
    #expect(model.shownFeedback?.id == first.id)
    model.receive(.failure(.storageUnavailable("/example/home/Elsewhere")))
    #expect(model.shownFeedback?.id == first.id)
    model.storageRepointed()
    #expect(model.shownFeedback == nil)
    model.receive(.failure(.storageUnavailable("/example/home/Thoughts")))
    #expect(model.shownFeedback?.id != first.id)
  }

  @Test func otherFailuresStayTransientHints() throws {
    let rig = try Self.rig()
    rig.fixture.model.storageRepointed()
    rig.fixture.model.receive(.failure(.notFound("x")))
    #expect(rig.fixture.model.storageProblem == nil)
    #expect(rig.fixture.model.feedback != nil)
  }

  @Test func aRetryWithTheFolderStillMissingNeverRestarts() async throws {
    let rig = try Self.rig()
    await rig.fixture.model.retryStorage()
    #expect(rig.log.events.isEmpty)
    #expect(rig.fixture.model.storageProblem == Self.message)
    #expect(!FileManager.default.fileExists(atPath: "/example/home/Thoughts"))
  }

  @Test func aRetryWithTheFolderBackRestartsAndClearsTheMessage() async throws {
    let rig = try Self.rig()
    rig.present.value = true
    await rig.fixture.model.retryStorage()
    #expect(rig.log.events == ["restart"])
    #expect(rig.fixture.model.storageProblem == nil)
    await rig.fixture.model.retryStorage()
    #expect(rig.log.events == ["restart"])
  }

  @Test func showingThePanelRetries() async throws {
    let rig = try Self.rig()
    rig.fixture.model.panelDidShow()
    await ListFixture.settle()
    #expect(rig.log.events.isEmpty)
    rig.present.value = true
    rig.fixture.model.panelDidHide()
    rig.fixture.model.panelDidShow()
    await ListFixture.settle()
    #expect(rig.log.events == ["restart"])
    #expect(rig.fixture.model.storageProblem == nil)
  }

  @Test func aMountRetriesThroughTheInjectedSignal() async throws {
    let rig = try Self.rig()
    rig.fixture.model.start()
    rig.mounts.fire()
    await ListFixture.settle()
    #expect(rig.log.events.isEmpty)
    rig.present.value = true
    rig.mounts.fire()
    await ListFixture.settle()
    #expect(rig.log.events == ["restart"])
    #expect(rig.fixture.model.storageProblem == nil)
  }
}

import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

struct StorageMoverTests {
  struct Late: Error {}

  @Test func aMoveThatThrowsAfterLandingStillRelocatesTheIndex() throws {
    let log = CallLog()
    let state = Folder(URL(fileURLWithPath: "/example/home/Thoughts"))
    let mover = StorageMover(
      current: { state.url },
      stop: { log.add("stop") },
      apply: {
        state.url = $0
        throw Late()
      },
      relocate: { log.add("relocate \($0.path)") },
      restart: { log.add("restart") })
    let destination = URL(fileURLWithPath: "/example/home/Moved")
    #expect(throws: Late.self) { try mover.run(to: destination) }
    #expect(log.events == ["stop", "relocate /example/home/Moved", "restart"])
  }

  @Test func aMoveThatNeverHappenedLeavesTheIndexAlone() throws {
    let log = CallLog()
    let mover = StorageMover(
      current: { URL(fileURLWithPath: "/example/home/Thoughts") },
      stop: { log.add("stop") },
      apply: { _ in throw ThoughtsError.folderNotEmpty(["a.txt"]) },
      relocate: { log.add("relocate \($0.path)") },
      restart: { log.add("restart") })
    #expect(throws: ThoughtsError.folderNotEmpty(["a.txt"])) {
      try mover.run(to: URL(fileURLWithPath: "/example/home/Other"))
    }
    #expect(log.events == ["stop", "restart"])
  }

  @Test func aRealMoveRelocatesAndFollowsTheNewFolder() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ThoughtsMoverTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let location = StorageLocation(appName: "ThoughtsTests", environment: [:], home: root)
    let log = CallLog()
    let mover = StorageMover(
      current: { try location.configuredFolder() },
      stop: { log.add("stop") },
      apply: { try location.move(to: $0) },
      relocate: { log.add("relocate \($0.lastPathComponent)") },
      restart: { log.add("restart") })
    let destination = root.appendingPathComponent("Moved", isDirectory: true)
    #expect(try mover.run(to: destination).lastPathComponent == "Moved")
    #expect(log.events == ["stop", "relocate Moved", "restart"])
    #expect(try location.resolve().lastPathComponent == "Moved")
  }

  @Test func aDestinationWithFilesIsRefusedAndNamesThem() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ThoughtsMoverTests-\(UUID().uuidString)", isDirectory: true)
    let destination = root.appendingPathComponent("Busy", isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data().write(to: destination.appendingPathComponent("notes.txt"))
    let location = StorageLocation(appName: "ThoughtsTests", environment: [:], home: root)
    let log = CallLog()
    let mover = StorageMover(
      current: { try location.configuredFolder() },
      stop: {},
      apply: { try location.move(to: $0) },
      relocate: { log.add("relocate \($0.lastPathComponent)") },
      restart: {})
    do {
      _ = try mover.run(to: destination)
      Issue.record("The move should have been refused")
    } catch {
      #expect(error as? ThoughtsError == .folderNotEmpty(["notes.txt"]))
      #expect(StorageMover.message(for: error).contains("notes.txt"))
    }
    #expect(log.events.isEmpty)
  }

  final class Folder: @unchecked Sendable {
    var url: URL

    init(_ url: URL) {
      self.url = url
    }
  }
}

@MainActor
struct SettingsModelTests {
  @Test func addedFoldersSkipDuplicatesOfTheScreenshotLocation() async throws {
    let system = FakeSystem()
    let model = try SettingsFixtures.settings(
      system: system, preferences: SettingsFixtures.preferences())
    let shots = URL(fileURLWithPath: "/example/home/Pictures/Shots", isDirectory: true)
    system.picks = [model.screenshotFolder, shots, shots]
    await model.addWatchedFolder()
    await model.addWatchedFolder()
    await model.addWatchedFolder()
    #expect(model.preferences.watchedFolders == [shots])
  }

  @Test func addingAFolderThatIsAlreadyWatchedSaysSo() async throws {
    let system = FakeSystem()
    let model = try SettingsFixtures.settings(
      system: system, preferences: SettingsFixtures.preferences())
    let shots = URL(fileURLWithPath: "/example/home/Pictures/Shots", isDirectory: true)
    system.picks = [model.screenshotFolder, shots, shots]
    await model.addWatchedFolder()
    #expect(model.watchedFolderNote == "Screenshots are already watched")
    await model.addWatchedFolder()
    #expect(model.watchedFolderNote == nil)
    await model.addWatchedFolder()
    #expect(model.watchedFolderNote == "That folder is already watched")
    #expect(model.selectedFolder == shots)
    model.removeSelectedFolder()
    #expect(model.watchedFolderNote == nil)
  }

  @Test func theScreenshotLocationRowCannotBeRemoved() async throws {
    let system = FakeSystem()
    let model = try SettingsFixtures.settings(
      system: system, preferences: SettingsFixtures.preferences())
    let shots = URL(fileURLWithPath: "/example/home/Pictures/Shots", isDirectory: true)
    system.picks = [shots]
    await model.addWatchedFolder()
    model.selectedFolder = model.screenshotFolder
    model.removeSelectedFolder()
    #expect(model.preferences.watchedFolders == [shots])
    model.selectedFolder = shots
    model.removeSelectedFolder()
    #expect(model.preferences.watchedFolders.isEmpty)
  }

  @Test func loginToggleFollowsTheServiceAndKeepsItsError() throws {
    let login = FakeLogin()
    let model = try SettingsFixtures.settings(
      system: FakeSystem(), preferences: SettingsFixtures.preferences(), login: login)
    model.setLogin(true)
    #expect(model.loginStatus == .on)
    login.status = .requiresApproval
    model.refresh()
    #expect(model.loginIsOn)
    model.openLoginSettings()
    #expect(login.openedSettings == 1)
    login.status = .off
    login.failure = StorageMoverTests.Late()
    model.setLogin(true)
    #expect(!model.loginIsOn)
    #expect(model.loginError != nil)
  }

  @Test func aRefusedMoveKeepsTheFolderAndListsTheBlockingFiles() async throws {
    let system = FakeSystem()
    system.picks = [URL(fileURLWithPath: "/example/home/Busy")]
    let mover = StorageMover(
      current: { URL(fileURLWithPath: "/example/home/Thoughts") },
      stop: {},
      apply: { _ in throw ThoughtsError.folderNotEmpty(["a.txt", "b.txt"]) },
      relocate: { _ in },
      restart: {})
    let model = try SettingsFixtures.settings(
      system: system, preferences: SettingsFixtures.preferences(), mover: mover)
    await model.moveStorage()
    #expect(model.storageText == "~/Thoughts")
    #expect(model.storageError?.contains("a.txt, b.txt") == true)
  }

  @Test func aMoveShowsTheNewFolderAndClearsTheError() async throws {
    let system = FakeSystem()
    let target = URL(fileURLWithPath: "/example/home/Notes", isDirectory: true)
    system.picks = [target]
    let state = StorageMoverTests.Folder(URL(fileURLWithPath: "/example/home/Thoughts"))
    let mover = StorageMover(
      current: { state.url },
      stop: {},
      apply: { state.url = $0 },
      relocate: { _ in },
      restart: {})
    let model = try SettingsFixtures.settings(
      system: system, preferences: SettingsFixtures.preferences(), mover: mover)
    await model.moveStorage()
    #expect(model.storageText == "~/Notes")
    #expect(model.storageError == nil)
  }

  @Test func pathsShortenTheHomeFolder() {
    #expect(
      PathText.abbreviated(
        URL(fileURLWithPath: "/example/home/Desktop"), home: SettingsFixtures.home) == "~/Desktop")
    #expect(
      PathText.abbreviated(URL(fileURLWithPath: "/Volumes/Work/Shots"), home: SettingsFixtures.home)
        == "/Volumes/Work/Shots")
  }
}

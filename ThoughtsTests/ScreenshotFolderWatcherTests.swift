import AppKit
import Foundation
import Testing

@testable import Thoughts

@MainActor
struct ScreenshotFolderWatcherTests {
  final class Found {
    var files: [URL] = []
  }

  struct Rig {
    let temp: TempFolder
    let folder: URL
    let watcher: ScreenshotFolderWatcher
    let found: Found
  }

  static func rig(storage: URL? = nil, existing: [String] = []) throws -> Rig {
    let temp = TempFolder()
    let folder = temp.url.appendingPathComponent("Shots", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for name in existing {
      try Data([1, 2, 3]).write(to: folder.appendingPathComponent(name))
    }
    let found = Found()
    let watcher = ScreenshotFolderWatcher(
      storageFolder: { storage }, settle: .milliseconds(20))
    watcher.onFile = { file, _ in found.files.append(file) }
    return Rig(temp: temp, folder: folder, watcher: watcher, found: found)
  }

  static func wait(for condition: () -> Bool) async {
    for _ in 0..<1000 where !condition() {
      try? await Task.sleep(for: .milliseconds(20))
    }
  }

  @Test func newImageIsReportedOnceItsSizeHolds() async throws {
    let rig = try Self.rig()
    rig.watcher.update(folders: [rig.folder])
    defer { rig.watcher.stop() }
    await rig.watcher.caughtUp()
    let file = rig.folder.appendingPathComponent("Screenshot 1.png")
    try ListFixture.png().write(to: file)
    await Self.wait { !rig.found.files.isEmpty }
    #expect(rig.found.files.map(\.lastPathComponent) == ["Screenshot 1.png"])
  }

  @Test func dotFilesNonImagesAndOlderFilesAreSkipped() async throws {
    let rig = try Self.rig(existing: ["old.png"])
    rig.watcher.update(folders: [rig.folder])
    defer { rig.watcher.stop() }
    await rig.watcher.caughtUp()
    try ListFixture.png().write(to: rig.folder.appendingPathComponent(".hidden.png"))
    try Data("notes".utf8).write(to: rig.folder.appendingPathComponent("notes.txt"))
    try Data([9]).write(to: rig.folder.appendingPathComponent("old.png"))
    let marker = rig.folder.appendingPathComponent("marker.png")
    try ListFixture.png().write(to: marker)
    await Self.wait { !rig.found.files.isEmpty }
    try? await Task.sleep(for: .milliseconds(300))
    #expect(rig.found.files.map(\.lastPathComponent) == ["marker.png"])
  }

  @Test func onlyDirectChildrenAreOffered() async throws {
    let rig = try Self.rig()
    rig.watcher.update(folders: [rig.folder])
    defer { rig.watcher.stop() }
    await rig.watcher.caughtUp()
    let nested = rig.folder.appendingPathComponent("Nested", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try ListFixture.png().write(to: nested.appendingPathComponent("deep.png"))
    try ListFixture.png().write(to: rig.folder.appendingPathComponent("top.png"))
    await Self.wait { !rig.found.files.isEmpty }
    try? await Task.sleep(for: .milliseconds(300))
    #expect(rig.found.files.map(\.lastPathComponent) == ["top.png"])
  }

  @Test func theStorageFolderIsNeverWatched() async throws {
    let temp = TempFolder()
    let storage = temp.url.appendingPathComponent("Thoughts", isDirectory: true)
    let other = temp.url.appendingPathComponent("Other", isDirectory: true)
    for folder in [storage, other] {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    let watcher = ScreenshotFolderWatcher(storageFolder: { storage })
    watcher.update(folders: [storage, other, other])
    defer { watcher.stop() }
    await watcher.caughtUp()
    #expect(watcher.watchedFolders.map(\.lastPathComponent) == ["Other"])
  }

  @Test func droppingAFolderStopsItsWatcher() async throws {
    let rig = try Self.rig()
    rig.watcher.update(folders: [rig.folder])
    await rig.watcher.caughtUp()
    #expect(rig.watcher.watchedFolders.count == 1)
    rig.watcher.update(folders: [])
    await rig.watcher.caughtUp()
    #expect(rig.watcher.watchedFolders.isEmpty)
  }

  @Test func aFolderIsListedOffTheMainThread() async throws {
    let temp = TempFolder()
    let folder = temp.url.appendingPathComponent("Desktop", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let reads = FolderReads()
    let watcher = ScreenshotFolderWatcher(
      storageFolder: { nil },
      listFolder: {
        reads.read($0)
        return []
      })
    watcher.update(folders: [folder])
    defer { watcher.stop() }
    await watcher.caughtUp()
    #expect(reads.urls == [folder])
    #expect(!reads.anyOnMain)
    #expect(watcher.watchedFolders == [folder])
  }

  @Test func aListingWaitingOnMacOSNeverHoldsUpTheMainThread() async throws {
    let temp = TempFolder()
    let folder = temp.url.appendingPathComponent("Documents", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let reads = FolderReads()
    reads.holdEachRead()
    defer { reads.releaseHeldReads() }
    let watcher = ScreenshotFolderWatcher(
      storageFolder: { nil },
      listFolder: {
        reads.read($0)
        return []
      })
    defer { watcher.stop() }
    let clock = ContinuousClock()
    let started = clock.now
    watcher.update(folders: [folder])
    let held = clock.now - started
    #expect(held < .milliseconds(500), "the main thread waited \(held) on a folder listing")
    reads.releaseHeldReads()
    await watcher.caughtUp()
    #expect(watcher.watchedFolders == [folder])
  }

  static func heldListing(of names: [String]) throws -> (
    temp: TempFolder, folders: [URL], hold: Hold, listed: CallLog,
    watcher: ScreenshotFolderWatcher
  ) {
    let temp = TempFolder()
    let folders = try names.map { name in
      let folder = temp.url.appendingPathComponent(name, isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      return folder
    }
    let held = ScreenshotFolderWatcher.key(folders[0])
    let hold = Hold()
    let listed = CallLog()
    let watcher = ScreenshotFolderWatcher(
      storageFolder: { nil },
      listFolder: { folder in
        listed.add(folder.lastPathComponent)
        if ScreenshotFolderWatcher.key(folder) == held { hold.pass() }
        return []
      })
    return (temp, folders, hold, listed, watcher)
  }

  static func settleListings(_ listed: CallLog, _ watcher: ScreenshotFolderWatcher) async {
    await watcher.caughtUp()
    for _ in 0..<10 {
      try? await Task.sleep(for: .milliseconds(20))
      await watcher.caughtUp()
    }
  }

  @Test func stoppingDuringAListingListsNoOtherFolder() async throws {
    let rig = try Self.heldListing(of: ["Alpha", "Bravo"])
    defer { rig.hold.release() }
    rig.watcher.update(folders: rig.folders)
    await rig.hold.waitForArrivals(1)
    rig.watcher.stop()
    rig.hold.release()
    await Self.settleListings(rig.listed, rig.watcher)
    #expect(rig.listed.events == ["Alpha"])
    #expect(rig.watcher.watchedFolders.isEmpty)
  }

  @Test func aNewerUpdateDuringAListingListsOnlyItsOwnFolders() async throws {
    let rig = try Self.heldListing(of: ["Alpha", "Bravo", "Charlie"])
    defer {
      rig.hold.release()
      rig.watcher.stop()
    }
    rig.watcher.update(folders: Array(rig.folders.prefix(2)))
    await rig.hold.waitForArrivals(1)
    rig.watcher.update(folders: [rig.folders[2]])
    rig.hold.release()
    await Self.settleListings(rig.listed, rig.watcher)
    #expect(rig.listed.events == ["Alpha", "Charlie"])
    #expect(rig.watcher.watchedFolders == [rig.folders[2]])
  }
}

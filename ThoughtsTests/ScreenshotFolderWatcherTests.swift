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
    let file = rig.folder.appendingPathComponent("Screenshot 1.png")
    try ListFixture.png().write(to: file)
    await Self.wait { !rig.found.files.isEmpty }
    #expect(rig.found.files.map(\.lastPathComponent) == ["Screenshot 1.png"])
  }

  @Test func dotFilesNonImagesAndOlderFilesAreSkipped() async throws {
    let rig = try Self.rig(existing: ["old.png"])
    rig.watcher.update(folders: [rig.folder])
    defer { rig.watcher.stop() }
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
    let nested = rig.folder.appendingPathComponent("Nested", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try ListFixture.png().write(to: nested.appendingPathComponent("deep.png"))
    try ListFixture.png().write(to: rig.folder.appendingPathComponent("top.png"))
    await Self.wait { !rig.found.files.isEmpty }
    try? await Task.sleep(for: .milliseconds(300))
    #expect(rig.found.files.map(\.lastPathComponent) == ["top.png"])
  }

  @Test func theStorageFolderIsNeverWatched() throws {
    let temp = TempFolder()
    let storage = temp.url.appendingPathComponent("Thoughts", isDirectory: true)
    let other = temp.url.appendingPathComponent("Other", isDirectory: true)
    for folder in [storage, other] {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    let watcher = ScreenshotFolderWatcher(storageFolder: { storage })
    watcher.update(folders: [storage, other, other])
    defer { watcher.stop() }
    #expect(watcher.watchedFolders.map(\.lastPathComponent) == ["Other"])
  }

  @Test func droppingAFolderStopsItsWatcher() throws {
    let rig = try Self.rig()
    rig.watcher.update(folders: [rig.folder])
    #expect(rig.watcher.watchedFolders.count == 1)
    rig.watcher.update(folders: [])
    #expect(rig.watcher.watchedFolders.isEmpty)
  }
}

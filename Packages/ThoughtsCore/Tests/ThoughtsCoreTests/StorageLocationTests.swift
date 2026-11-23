import Darwin
import Foundation
import Testing

@testable import ThoughtsCore

private final class Fixture {
  let home: URL

  init() {
    home = FileManager.default.temporaryDirectory
      .appendingPathComponent("storage-location-tests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
  }

  deinit {
    try? FileManager.default.removeItem(at: home)
  }

  func location(
    _ environment: [String: String] = [:], appName: String = "Thoughts"
  ) -> StorageLocation {
    StorageLocation(appName: appName, environment: environment, home: home)
  }

  func url(_ name: String) -> URL {
    home.appendingPathComponent(name)
  }

  func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }

  func write(_ text: String, to url: URL) {
    try! FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! text.write(to: url, atomically: false, encoding: .utf8)
  }

  func text(_ url: URL) -> String {
    try! String(contentsOf: url, encoding: .utf8)
  }

  func names(_ url: URL) -> [String] {
    try! FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
  }

  func settings(_ location: StorageLocation) -> [String: Any] {
    let data = try! Data(contentsOf: location.settingsFile)
    return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
  }

  func isSymlink(_ url: URL) -> Bool {
    (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
  }
}

@Test func defaultsToThoughtsInHome() throws {
  let fixture = Fixture()
  let location = fixture.location()
  let folder = try location.resolve()
  #expect(folder.path == fixture.url("Thoughts").path)
  #expect(location.supportFolder.path == fixture.url("Library/Application Support/Thoughts").path)
  #expect(location.settingsFile.lastPathComponent == "settings.json")
  #expect(
    location.indexURL.path == location.supportFolder.appendingPathComponent("index.sqlite").path)
}

@Test func debugNameKeepsItsOwnFolders() throws {
  let fixture = Fixture()
  let location = fixture.location(appName: "Thoughts Dev")
  let folder = try location.resolve()
  #expect(folder.path == fixture.url("Thoughts Dev").path)
  #expect(
    location.supportFolder.path == fixture.url("Library/Application Support/Thoughts Dev").path)
  #expect(location.supportFolder != fixture.location().supportFolder)
}

@Test func environmentWins() throws {
  let fixture = Fixture()
  let fromSettings = fixture.url("FromSettings")
  let fromEnvironment = fixture.url("FromEnvironment")
  let plain = fixture.location()
  try plain.setFolder(fromSettings)
  #expect(try plain.resolve().path == fromSettings.path)
  let overridden = fixture.location(["THOUGHTS_DIR": fromEnvironment.path])
  #expect(try overridden.resolve().path == fromEnvironment.path)
  #expect(fixture.exists(fromEnvironment))
}

@Test func tildeExpandsToHome() throws {
  let fixture = Fixture()
  let location = fixture.location(["THOUGHTS_DIR": "~/Elsewhere/../Notes"])
  #expect(try location.resolve().path == fixture.url("Notes").path)
}

@Test func createsMissingDefaultFolder() throws {
  let fixture = Fixture()
  #expect(!fixture.exists(fixture.url("Thoughts")))
  _ = try fixture.location().resolve()
  #expect(fixture.exists(fixture.url("Thoughts")))
}

@Test func missingFolderOnVolumeIsUnavailable() {
  let fixture = Fixture()
  let location = fixture.location(["THOUGHTS_DIR": "/Volumes/NoSuchDrive/Thoughts"])
  #expect(throws: ThoughtsError.storageUnavailable("/Volumes/NoSuchDrive/Thoughts")) {
    try location.resolve()
  }
  #expect(!FileManager.default.fileExists(atPath: "/Volumes/NoSuchDrive"))
}

@Test func setFolderWritesSettingsAndKeepsOtherKeys() throws {
  let fixture = Fixture()
  let location = fixture.location()
  fixture.write(#"{"folder": "/old", "theme": "dark"}"#, to: location.settingsFile)
  try location.setFolder(fixture.url("New"))
  let settings = fixture.settings(location)
  #expect(settings["folder"] as? String == fixture.url("New").path)
  #expect(settings["theme"] as? String == "dark")
}

@Test func unreadableSettingsThrows() {
  let fixture = Fixture()
  let location = fixture.location()
  fixture.write("{not json", to: location.settingsFile)
  #expect {
    try location.resolve()
  } throws: { error in
    guard case ThoughtsError.io(let reason) = error else { return false }
    return reason.contains("settings.json")
  }
  #expect(!fixture.exists(fixture.url("Thoughts")))
}

@Test func thoughtsDirGetsItsOwnIndex() {
  let fixture = Fixture()
  let plain = fixture.location()
  let custom = fixture.location(["THOUGHTS_DIR": fixture.url("Custom").path])
  let other = fixture.location(["THOUGHTS_DIR": fixture.url("Other").path])
  #expect(custom.indexURL != plain.indexURL)
  #expect(custom.indexURL != other.indexURL)
  #expect(custom.indexURL.deletingLastPathComponent().lastPathComponent == "Indexes")
  #expect(custom.indexURL.pathExtension == "sqlite")
  #expect(custom.indexURL.deletingPathExtension().lastPathComponent.count == 16)
  #expect(
    custom.indexURL == fixture.location(["THOUGHTS_DIR": fixture.url("Custom").path]).indexURL)
}

@Test func moveLeavesSymlinkSoOldPathsWork() throws {
  let fixture = Fixture()
  let location = fixture.location()
  let old = try location.resolve()
  fixture.write("hello", to: old.appendingPathComponent("a.md"))
  fixture.write("png", to: old.appendingPathComponent("a.png"))
  fixture.write("", to: old.appendingPathComponent(".DS_Store"))
  let destination = fixture.url("Moved/Thoughts")
  try location.move(to: destination)
  #expect(fixture.isSymlink(old))
  #expect(fixture.text(old.appendingPathComponent("a.md")) == "hello")
  #expect(fixture.text(destination.appendingPathComponent("a.md")) == "hello")
  #expect(try location.resolve().path == destination.path)
  #expect(fixture.settings(location)["folder"] as? String == destination.path)
}

@Test func moveRefusesFolderWithOtherFiles() throws {
  let fixture = Fixture()
  let location = fixture.location()
  let old = try location.resolve()
  fixture.write("x", to: old.appendingPathComponent("a.md"))
  fixture.write("x", to: old.appendingPathComponent("notes.txt"))
  #expect(throws: ThoughtsError.folderNotEmpty(["notes.txt"])) {
    try location.move(to: fixture.url("Moved"))
  }
  #expect(fixture.exists(old.appendingPathComponent("a.md")))
  #expect(!fixture.exists(fixture.url("Moved")))
}

@Test func moveRefusesNonEmptyDestination() throws {
  let fixture = Fixture()
  let location = fixture.location()
  let old = try location.resolve()
  fixture.write("x", to: old.appendingPathComponent("a.md"))
  let destination = fixture.url("Taken")
  fixture.write("x", to: destination.appendingPathComponent("b.md"))
  #expect(throws: ThoughtsError.folderNotEmpty(["b.md"])) {
    try location.move(to: destination)
  }
  #expect(!fixture.isSymlink(old))
  #expect(fixture.exists(old.appendingPathComponent("a.md")))
}

@Test func moveIntoEmptyExistingFolderWorks() throws {
  let fixture = Fixture()
  let location = fixture.location()
  let old = try location.resolve()
  fixture.write("x", to: old.appendingPathComponent("a.md"))
  let destination = fixture.url("Empty")
  try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
  try location.move(to: destination)
  #expect(fixture.names(destination) == ["a.md"])
}

@Test func moveAcrossVolumesCopiesThenRemoves() throws {
  let fixture = Fixture()
  let location = fixture.location()
  let old = try location.resolve()
  fixture.write("one", to: old.appendingPathComponent("a.md"))
  fixture.write("png", to: old.appendingPathComponent("a.png"))
  let destination = fixture.url("Elsewhere/Thoughts")
  try location.move(to: destination, rename: { _, _ in EXDEV })
  #expect(fixture.isSymlink(old))
  #expect(fixture.names(destination) == ["a.md", "a.png"])
  #expect(fixture.text(old.appendingPathComponent("a.md")) == "one")
  #expect(fixture.settings(location)["folder"] as? String == destination.path)
  #expect(try location.resolve().path == destination.path)
}

@Test func crossVolumeMoveKeepsFilesWrittenMidMove() throws {
  let fixture = Fixture()
  let location = fixture.location()
  let old = try location.resolve()
  fixture.write("one", to: old.appendingPathComponent("a.md"))
  let destination = fixture.url("Elsewhere/Thoughts")
  #expect {
    try location.move(
      to: destination, rename: { _, _ in EXDEV },
      afterCopy: { fixture.write("late", to: old.appendingPathComponent("late.md")) })
  } throws: { error in
    guard case ThoughtsError.io(let reason) = error else { return false }
    return reason.contains("late.md")
  }
  #expect(!fixture.isSymlink(old))
  #expect(fixture.names(old) == ["late.md"])
  #expect(fixture.text(old.appendingPathComponent("late.md")) == "late")
  #expect(fixture.names(destination) == ["a.md"])
  #expect(fixture.settings(location)["folder"] as? String == destination.path)
}

@Test func crossVolumeMoveRollsBackWhenAFileChangesMidCopy() throws {
  let fixture = Fixture()
  let location = fixture.location()
  let old = try location.resolve()
  fixture.write("one", to: old.appendingPathComponent("a.md"))
  let destination = fixture.url("Elsewhere/Thoughts")
  #expect(throws: ThoughtsError.io("a.md changed while it was being copied")) {
    try location.move(
      to: destination, rename: { _, _ in EXDEV },
      afterCopy: { fixture.write("two", to: old.appendingPathComponent("a.md")) })
  }
  #expect(fixture.text(old.appendingPathComponent("a.md")) == "two")
  #expect(!fixture.exists(destination))
  #expect(!fixture.exists(location.settingsFile))
}

@Test func moveRefusesWhileThoughtsDirIsSet() throws {
  let fixture = Fixture()
  let custom = fixture.url("Custom")
  let location = fixture.location(["THOUGHTS_DIR": custom.path])
  try location.setFolder(fixture.url("Real"))
  #expect {
    try location.move(to: fixture.url("Elsewhere"))
  } throws: { error in
    guard case ThoughtsError.io(let reason) = error else { return false }
    return reason.contains("THOUGHTS_DIR")
  }
  #expect(!fixture.exists(custom))
  #expect(!fixture.exists(fixture.url("Elsewhere")))
  #expect(fixture.settings(location)["folder"] as? String == fixture.url("Real").path)
}

@Test func moveBackToOldPathMovesTheFolder() throws {
  let fixture = Fixture()
  let location = fixture.location()
  let a = try location.resolve()
  let b = fixture.url("Moved")
  fixture.write("hello", to: a.appendingPathComponent("a.md"))
  try location.move(to: b)
  try location.move(to: a)
  #expect(!fixture.isSymlink(a))
  #expect(fixture.text(a.appendingPathComponent("a.md")) == "hello")
  #expect(fixture.isSymlink(b))
  #expect(fixture.text(b.appendingPathComponent("a.md")) == "hello")
  #expect(try location.resolve().path == a.path)
  #expect(fixture.settings(location)["folder"] as? String == a.path)
}

@Test func moveRefusesSymlinkToElsewhere() throws {
  let fixture = Fixture()
  let location = fixture.location()
  let old = try location.resolve()
  fixture.write("x", to: old.appendingPathComponent("a.md"))
  let elsewhere = fixture.url("Elsewhere")
  try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: false)
  let link = fixture.url("Link")
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: elsewhere)
  #expect(throws: ThoughtsError.folderNotEmpty(["Link"])) {
    try location.move(to: link)
  }
  #expect(fixture.isSymlink(link))
  #expect(fixture.exists(old.appendingPathComponent("a.md")))
}

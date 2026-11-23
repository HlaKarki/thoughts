import Foundation
import Testing

@testable import Thoughts

@MainActor
struct InstalledIDEsTests {
  static func makeApp(_ name: String, bundleID: String, in folder: URL) throws {
    let contents = folder.appendingPathComponent("\(name).app/Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist: [String: Any] = ["CFBundleIdentifier": bundleID, "CFBundleName": name]
    try (plist as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"))
  }

  @Test func scanReadsOneLevelAndSkipsMissingFolders() async throws {
    let root = TempFolder()
    let applications = root.url.appendingPathComponent("Applications", isDirectory: true)
    let toolbox = root.url.appendingPathComponent("Toolbox", isDirectory: true)
    try Self.makeApp("Safari", bundleID: "com.apple.Safari", in: applications)
    try Self.makeApp("PyCharm", bundleID: "com.jetbrains.pycharm", in: toolbox)
    let nested = applications.appendingPathComponent("Folder", isDirectory: true)
    try Self.makeApp("Deep", bundleID: "com.jetbrains.deep", in: nested)
    let missing = root.url.appendingPathComponent("Missing", isDirectory: true)
    let ids = InstalledApplications.bundleIDs(in: [applications, toolbox, missing])
    #expect(Set(ids) == ["com.apple.Safari", "com.jetbrains.pycharm"])
  }

  @Test func modelsShowTheNoteOnlyAfterAScanFindsAnIDE() async throws {
    let root = TempFolder()
    let applications = root.url.appendingPathComponent("Applications", isDirectory: true)
    try Self.makeApp("Studio", bundleID: "com.google.android.studio", in: applications)
    let scan = InstalledIDEs()
    let firstRun = try SettingsFixtures.firstRun(
      system: FakeSystem(), preferences: SettingsFixtures.preferences(), installedIDEs: scan)
    let settings = try SettingsFixtures.settings(
      system: FakeSystem(), preferences: SettingsFixtures.preferences(), installedIDEs: scan)
    #expect(!firstRun.showsJetBrainsNote)
    #expect(!settings.showsJetBrainsNote)
    await scan.scan(folders: [applications])
    #expect(firstRun.showsJetBrainsNote)
    #expect(settings.showsJetBrainsNote)
  }

  @Test func scanWithoutAnIDEKeepsTheNoteHidden() async throws {
    let root = TempFolder()
    let applications = root.url.appendingPathComponent("Applications", isDirectory: true)
    try Self.makeApp("Code", bundleID: "com.microsoft.VSCode", in: applications)
    let scan = InstalledIDEs()
    await scan.scan(folders: [applications])
    #expect(!scan.hasJetBrains)
  }
}

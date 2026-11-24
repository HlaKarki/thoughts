import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct OfferCenterTests {
  static let page = Source(app: "Preview", bundleID: "com.example.preview")

  @MainActor
  final class Plays {
    var count = 0
    var changes: [Offer?] = []
  }

  struct Rig {
    let fixture: ListFixture
    let board: NSPasteboard
    let center: OfferCenter
    let preferences: Preferences
    let plays: Plays
    let temp: TempFolder
  }

  static func rig(behavior: NSPasteboard.AccessBehavior = .ask) throws -> Rig {
    let fixture = try ListFixture()
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    let name = "thoughts.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    let preferences = Preferences(defaults: defaults)
    let plays = Plays()
    let temp = TempFolder()
    try FileManager.default.createDirectory(at: temp.url, withIntermediateDirectories: true)
    let watcher = ClipboardWatcher(pasteboard: board, accessBehavior: { behavior })
    let center = OfferCenter(
      preferences: preferences, input: fixture.input, clipboard: watcher,
      screenshots: ScreenshotFolderWatcher(storageFolder: { fixture.folder }),
      sound: SavedSound(preferences: preferences, player: { plays.count += 1 }),
      source: { page }, pasteboard: board,
      location: ScreenshotLocation(defaults: nil, home: temp.url),
      accessBehavior: { behavior })
    center.onChange = { offer, _ in plays.changes.append(offer) }
    return Rig(
      fixture: fixture, board: board, center: center, preferences: preferences, plays: plays,
      temp: temp)
  }

  static func wait(for condition: () -> Bool) async {
    for _ in 0..<150 where !condition() {
      try? await Task.sleep(for: .milliseconds(20))
    }
  }

  static func writeShot(in temp: TempFolder, name: String = "Screenshot.png") throws -> URL {
    let file = temp.url.appendingPathComponent(name)
    try ListFixture.png().write(to: file)
    return file
  }

  @Test func clipboardOfferKeepsTheImageWithTheSourceRecordedWhenItArrived() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    rig.board.clearContents()
    rig.board.setData(try ListFixture.png(), forType: .png)
    let count = rig.board.changeCount
    rig.center.receive(.clipboard(changeCount: count, file: nil, at: Date()))
    await Self.wait { rig.center.current != nil }
    #expect(rig.center.current?.changeCount == count)
    #expect(rig.center.current?.source == Self.page)
    let thought = try await rig.center.accept()
    guard case .image = thought.content else {
      Issue.record("expected an image thought")
      return
    }
    #expect(thought.source?.app == "Preview")
    #expect(rig.plays.count == 1)
    #expect(rig.center.current == nil)
    rig.center.receive(.clipboard(changeCount: count, file: nil, at: Date()))
    try? await Task.sleep(for: .milliseconds(100))
    #expect(rig.center.current == nil)
  }

  @Test func acceptNeverReadsAnImageMarkedConcealed() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    rig.board.clearContents()
    rig.board.setData(try ListFixture.png(), forType: .png)
    rig.board.setData(Data(), forType: NSPasteboard.PasteboardType(ClipboardTypes.concealed))
    rig.center.receive(.clipboard(changeCount: rig.board.changeCount, file: nil, at: Date()))
    await Self.wait { rig.center.current != nil }
    await #expect(throws: ThoughtsError.self) {
      _ = try await rig.center.accept()
    }
    #expect(try rig.fixture.store.entries().isEmpty)
  }

  @Test func acceptSaysWhyWhenMacOSRefusedThePaste() async throws {
    let rig = try Self.rig(behavior: .alwaysDeny)
    defer { rig.board.releaseGlobally() }
    rig.board.clearContents()
    rig.board.setString("nothing readable as an image", forType: .string)
    let count = rig.board.changeCount
    rig.center.receive(.clipboard(changeCount: count, file: nil, at: Date()))
    await Self.wait { rig.center.current != nil }
    await #expect(throws: ThoughtsError.io(CaptureCoordinator.pasteRefusedMessage)) {
      _ = try await rig.center.accept()
    }
  }

  @Test func acceptThrowsWhenTheClipboardMoved() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    rig.board.clearContents()
    rig.board.setData(try ListFixture.png(), forType: .png)
    rig.center.receive(.clipboard(changeCount: rig.board.changeCount, file: nil, at: Date()))
    await Self.wait { rig.center.current != nil }
    rig.board.clearContents()
    rig.board.setString("something else", forType: .string)
    await #expect(throws: ThoughtsError.clipboardChanged) {
      _ = try await rig.center.accept()
    }
    #expect(rig.plays.count == 0)
    #expect(try rig.fixture.store.entries().isEmpty)
  }

  @Test func fileOfferAddsACopyAndNeverMovesTheFile() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    let file = try Self.writeShot(in: rig.temp)
    rig.center.receive(.file(file, at: Date()))
    await Self.wait { rig.center.current != nil }
    let thought = try await rig.center.accept()
    #expect(FileManager.default.fileExists(atPath: file.path))
    #expect(thought.source?.file == file.path)
    #expect(thought.source?.app == "Preview")
    guard case .image(let name, _) = thought.content else {
      Issue.record("expected an image thought")
      return
    }
    let copy = rig.fixture.folder.appendingPathComponent(name)
    #expect(try Data(contentsOf: copy) == Data(contentsOf: file))
    #expect(rig.plays.count == 1)
  }

  @Test func clipboardAndFileFromOneScreenshotAreOneOfferThatKeepsTheFile() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    let file = try Self.writeShot(in: rig.temp)
    rig.board.clearContents()
    rig.board.setData(try ListFixture.png(), forType: .png)
    let now = Date()
    rig.center.receive(.clipboard(changeCount: rig.board.changeCount, file: nil, at: now))
    rig.center.receive(.file(file, at: now.addingTimeInterval(0.8)))
    await Self.wait { rig.center.current?.file != nil }
    #expect(rig.center.current?.file == file)
    #expect(rig.center.current?.changeCount == rig.board.changeCount)
    let thought = try await rig.center.accept()
    #expect(thought.source?.file == file.path)
  }

  @Test func offersTurnedOffMakeNoOffers() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    rig.preferences.offersEnabled = false
    rig.center.receive(.file(try Self.writeShot(in: rig.temp), at: Date()))
    try? await Task.sleep(for: .milliseconds(150))
    #expect(rig.center.current == nil)
    #expect(rig.plays.changes.isEmpty)
  }

  @Test func ownChangeAndHandSavesDropTheOffer() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    rig.center.receive(.clipboard(changeCount: 31, file: nil, at: Date()))
    await Self.wait { rig.center.current != nil }
    rig.center.noteOwn(31)
    #expect(rig.center.current == nil)
    #expect(rig.plays.changes.last == .some(nil))
    rig.center.receive(.clipboard(changeCount: 32, file: nil, at: Date().addingTimeInterval(10)))
    await Self.wait { rig.center.current != nil }
    rig.center.noteSaved(changeCount: 32, file: nil)
    #expect(rig.center.current == nil)
  }

  @Test func handSavingTheOfferedFileDropsTheOffer() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    let file = try Self.writeShot(in: rig.temp)
    rig.center.receive(.file(file, at: Date()))
    await Self.wait { rig.center.current != nil }
    let alias = rig.temp.url.appendingPathComponent(
      "../\(rig.temp.url.lastPathComponent)/\(file.lastPathComponent)")
    rig.center.noteSaved(changeCount: nil, file: alias)
    #expect(rig.center.current == nil)
    rig.center.receive(.file(file, at: Date().addingTimeInterval(30)))
    try? await Task.sleep(for: .milliseconds(100))
    #expect(rig.center.current == nil)
  }

  @Test func savingAnotherFileKeepsTheOffer() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    let file = try Self.writeShot(in: rig.temp)
    rig.center.receive(.file(file, at: Date()))
    await Self.wait { rig.center.current != nil }
    rig.center.noteSaved(
      changeCount: nil, file: rig.temp.url.appendingPathComponent("other.png"))
    #expect(rig.center.current?.file == file)
  }

  @Test func fileOfferShowsAThumbnailAndClipboardOfferOnlyWhenAlwaysAllowed() async throws {
    let gated = try Self.rig(behavior: .ask)
    defer { gated.board.releaseGlobally() }
    gated.board.clearContents()
    gated.board.setData(try ListFixture.png(), forType: .png)
    gated.center.receive(
      .clipboard(changeCount: gated.board.changeCount, file: nil, at: Date()))
    await Self.wait { gated.center.current != nil }
    #expect(gated.center.thumbnail == nil)

    let open = try Self.rig(behavior: .alwaysAllow)
    defer { open.board.releaseGlobally() }
    open.board.clearContents()
    open.board.setData(try ListFixture.png(), forType: .png)
    open.center.receive(.clipboard(changeCount: open.board.changeCount, file: nil, at: Date()))
    await Self.wait { open.center.current != nil }
    #expect(open.center.thumbnail != nil)

    let shot = try Self.writeShot(in: gated.temp)
    gated.center.receive(.file(shot, at: Date().addingTimeInterval(20)))
    await Self.wait { gated.center.thumbnail != nil }
    #expect(gated.center.thumbnail != nil)
  }

  @Test func acceptWithNoOfferThrows() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    await #expect(throws: ThoughtsError.self) { _ = try await rig.center.accept() }
  }

  @Test func watchedFoldersStartWithTheScreenshotLocationAndAddTheUsersOwn() throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
    let extra = rig.temp.url.appendingPathComponent("Extra", isDirectory: true)
    rig.preferences.watchedFolders = [extra, extra]
    let folders = rig.center.folders()
    #expect(folders.first?.lastPathComponent == "Desktop")
    #expect(folders.dropFirst().map(\.lastPathComponent) == ["Extra"])
  }
}

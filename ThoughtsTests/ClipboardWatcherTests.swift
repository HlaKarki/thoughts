import AppKit
import Foundation
import Testing
import ThoughtsCore
import UniformTypeIdentifiers

@testable import Thoughts

@MainActor
struct ClipboardWatcherTests {
  final class Signals {
    var all: [OfferSignal] = []
  }

  struct Rig {
    let board: NSPasteboard
    let watcher: ClipboardWatcher
    let signals: Signals
  }

  static let now = Date(timeIntervalSince1970: 1_795_000_000)

  static func rig(
    behavior: NSPasteboard.AccessBehavior = .alwaysAllow,
    type: UTType? = nil,
    own: Set<Int> = []
  ) -> Rig {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    let signals = Signals()
    let watcher = ClipboardWatcher(
      pasteboard: board, accessBehavior: { behavior }, isOwnChange: { own.contains($0) },
      contentType: { type }, now: { now })
    watcher.onSignal = { signals.all.append($0) }
    return Rig(board: board, watcher: watcher, signals: signals)
  }

  @discardableResult
  static func copyFile(named name: String, to board: NSPasteboard) throws -> TempFolder {
    let temp = TempFolder()
    try FileManager.default.createDirectory(at: temp.url, withIntermediateDirectories: true)
    let file = temp.url.appendingPathComponent(name)
    try Data([1]).write(to: file)
    board.clearContents()
    board.writeObjects([file as NSURL])
    return temp
  }

  static func settle() async {
    try? await Task.sleep(for: .milliseconds(150))
  }

  @Test func copiedImageDataOffersAndIsRemembered() async throws {
    let rig = Self.rig()
    defer { rig.board.releaseGlobally() }
    rig.board.clearContents()
    rig.board.setData(try ListFixture.png(), forType: .png)
    let count = rig.board.changeCount
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all == [.clipboard(changeCount: count, file: nil, at: Self.now)])
    #expect(rig.watcher.lastImage == ClipboardImage(changeCount: count, seen: Self.now))
  }

  @Test func copiedTextNeverOffersOrCountsAsAnImage() async {
    let rig = Self.rig()
    defer { rig.board.releaseGlobally() }
    rig.board.clearContents()
    rig.board.setString("just words", forType: .string)
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all.isEmpty)
    #expect(rig.watcher.lastImage == nil)
  }

  @Test func copiedImageFileOffersWhenItsContentTypeIsAnImage() async throws {
    let rig = Self.rig(type: .png)
    defer { rig.board.releaseGlobally() }
    try Self.copyFile(named: "example.png", to: rig.board)
    let count = rig.board.changeCount
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all == [.clipboard(changeCount: count, file: nil, at: Self.now)])
  }

  @Test func copiedNonImageFileNeverOffers() async throws {
    let rig = Self.rig(type: .pdf)
    defer { rig.board.releaseGlobally() }
    try Self.copyFile(named: "example.pdf", to: rig.board)
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all.isEmpty)
    #expect(rig.watcher.lastImage == nil)
  }

  @Test func ownChangeIsRememberedButNeverOffered() async throws {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    let signals = Signals()
    let watcher = ClipboardWatcher(
      pasteboard: board, accessBehavior: { .alwaysAllow }, isOwnChange: { _ in true },
      contentType: { nil }, now: { Self.now })
    watcher.onSignal = { signals.all.append($0) }
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    let count = board.changeCount
    watcher.poll()
    await Self.settle()
    #expect(signals.all.isEmpty)
    #expect(watcher.lastImage == ClipboardImage(changeCount: count, seen: Self.now))
  }

  @Test func finderCopyOfANonImageFileWithItsIconIsNotAnImage() async throws {
    let rig = Self.rig(type: .pdf)
    defer { rig.board.releaseGlobally() }
    let temp = try Self.copyFile(named: "report.pdf", to: rig.board)
    rig.board.addTypes([.tiff], owner: nil)
    rig.board.setData(try ListFixture.tiff(), forType: .tiff)
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all.isEmpty)
    #expect(rig.watcher.lastImage == nil)
    withExtendedLifetime(temp) {}
  }

  @Test func fileCopyWithNoDetectedTypeIsDecidedByItsExtension() async throws {
    let rig = Self.rig(type: nil)
    defer { rig.board.releaseGlobally() }
    let temp = try Self.copyFile(named: "notes.txt", to: rig.board)
    rig.board.addTypes([.tiff], owner: nil)
    rig.board.setData(try ListFixture.tiff(), forType: .tiff)
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all.isEmpty)
    withExtendedLifetime(temp) {}
  }

  @Test func gatedPathRecordsEveryUnclassifiedChangeAsACandidate() async {
    let rig = Self.rig(behavior: .ask)
    defer { rig.board.releaseGlobally() }
    rig.board.clearContents()
    rig.board.setString("could be anything", forType: .string)
    let count = rig.board.changeCount
    rig.watcher.poll()
    #expect(rig.watcher.lastImage == ClipboardImage(changeCount: count, seen: Self.now))
    await Self.settle()
    #expect(rig.signals.all.isEmpty)
    #expect(rig.watcher.lastImage == ClipboardImage(changeCount: count, seen: Self.now))
  }

  @Test func gatedPathOffersOnlyWhatTheDetectAPIProvesIsAnImage() async throws {
    let rig = Self.rig(behavior: .ask, type: .jpeg)
    defer { rig.board.releaseGlobally() }
    try Self.copyFile(named: "photo.jpg", to: rig.board)
    let count = rig.board.changeCount
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all == [.clipboard(changeCount: count, file: nil, at: Self.now)])
  }

  @Test func gatedPathDropsTheCandidateWhenDetectFindsANonImageFile() async throws {
    let rig = Self.rig(behavior: .ask, type: .pdf)
    defer { rig.board.releaseGlobally() }
    try Self.copyFile(named: "example.pdf", to: rig.board)
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all.isEmpty)
    #expect(rig.watcher.lastImage == nil)
  }

  @Test func pollSkipsWhilePausedAndPicksTheChangeUpAfterwards() async throws {
    let rig = Self.rig()
    defer { rig.board.releaseGlobally() }
    var paused = true
    rig.watcher.isPaused = { paused }
    rig.board.clearContents()
    rig.board.setData(try ListFixture.png(), forType: .png)
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all.isEmpty)
    paused = false
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all.count == 1)
  }

  @Test func contentAlreadyOnTheClipboardAtStartIsNotOffered() async throws {
    let rig = Self.rig()
    defer { rig.board.releaseGlobally() }
    rig.board.clearContents()
    rig.board.setData(try ListFixture.png(), forType: .png)
    rig.watcher.start()
    defer { rig.watcher.stop() }
    rig.watcher.poll()
    await Self.settle()
    #expect(rig.signals.all.isEmpty)
  }

  @Test func detectAPIReportsTheContentTypeOfACopiedFile() async throws {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    let temp = try Self.copyFile(named: "example.png", to: board)
    let type = await PasteboardDetect.contentType(of: board)
    #expect(type?.conforms(to: .image) == true)
    withExtendedLifetime(temp) {}
  }
}

import AppKit
import ObjectiveC
import Testing
import ThoughtsCore

@testable import Thoughts

final class MainThreadPasteboardReads: @unchecked Sendable {
  static let shared = MainThreadPasteboardReads()

  private let lock = NSLock()
  private var watched: Set<String> = []
  private var seen: [String: [String]] = [:]

  private init() {
    Self.swap(#selector(NSPasteboard.data(forType:)), #selector(NSPasteboard.watchedData(forType:)))
    Self.swap(
      #selector(NSPasteboard.string(forType:)), #selector(NSPasteboard.watchedString(forType:)))
    Self.swap(
      #selector(NSPasteboard.readObjects(forClasses:options:)),
      #selector(NSPasteboard.watchedReadObjects(forClasses:options:)))
    Self.swap(
      #selector(getter: NSPasteboard.pasteboardItems),
      #selector(getter: NSPasteboard.watchedPasteboardItems))
  }

  private static func swap(_ original: Selector, _ replacement: Selector) {
    guard let from = class_getInstanceMethod(NSPasteboard.self, original),
      let to = class_getInstanceMethod(NSPasteboard.self, replacement)
    else { return }
    method_exchangeImplementations(from, to)
  }

  func watch(_ board: NSPasteboard) {
    lock.withLock { watched.insert(board.name.rawValue) }
  }

  func reads(_ board: NSPasteboard) -> [String] {
    lock.withLock {
      watched.remove(board.name.rawValue)
      return seen.removeValue(forKey: board.name.rawValue) ?? []
    }
  }

  func note(_ board: NSPasteboard, _ call: String) {
    guard Thread.isMainThread else { return }
    let name = board.name.rawValue
    lock.withLock {
      guard watched.contains(name) else { return }
      seen[name, default: []].append(call)
    }
  }
}

extension NSPasteboard {
  @objc dynamic func watchedData(forType type: NSPasteboard.PasteboardType) -> Data? {
    MainThreadPasteboardReads.shared.note(self, "data")
    return watchedData(forType: type)
  }

  @objc dynamic func watchedString(forType type: NSPasteboard.PasteboardType) -> String? {
    MainThreadPasteboardReads.shared.note(self, "string")
    return watchedString(forType: type)
  }

  @objc dynamic func watchedReadObjects(
    forClasses classes: [AnyClass], options: [NSPasteboard.ReadingOptionKey: Any]?
  ) -> [Any]? {
    MainThreadPasteboardReads.shared.note(self, "readObjects")
    return watchedReadObjects(forClasses: classes, options: options)
  }

  @objc dynamic var watchedPasteboardItems: [NSPasteboardItem]? {
    MainThreadPasteboardReads.shared.note(self, "pasteboardItems")
    return watchedPasteboardItems
  }
}

@MainActor
struct PasteboardReadThreadTests {
  static let reads = MainThreadPasteboardReads.shared

  @Test func theCaptureKeyReadsACopiedImageOffTheMainThread() async throws {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    let count = board.changeCount
    let fixture = try ListFixture()
    let reader = CaptureCoordinatorTests.FakeReader()
    reader.probeResult = .empty
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let coordinator = CaptureCoordinator(
      frontmost: { CaptureCoordinatorTests.editor }, ownBundleID: CaptureCoordinatorTests.own,
      ownWindowIsKey: { false }, reader: reader, source: { CaptureCoordinatorTests.page },
      input: fixture.input, writer: PasteboardWriter(pasteboard: board),
      sound: SavedSound(preferences: Preferences(defaults: defaults), player: {}),
      pasteboard: board, now: { ListFixture.now },
      clipboardCopy: {
        ClipboardCopy(
          changeCount: count, seen: ListFixture.now.addingTimeInterval(-30), kind: .image)
      },
      accessBehavior: { .ask })
    Self.reads.watch(board)
    let outcome = await coordinator.capture()
    let onMain = Self.reads.reads(board)
    guard case .saved(let thought) = outcome, case .image = thought.content else {
      Issue.record("expected an image, got \(outcome)")
      return
    }
    #expect(onMain.isEmpty)
  }

  @Test func theCaptureKeyReadsCopiedTextOffTheMainThread() async throws {
    let rig = try CaptureCoordinatorTests.textRig(text: "  ls -la\n", access: .ask)
    defer { rig.board.releaseGlobally() }
    Self.reads.watch(rig.board)
    let outcome = await rig.coordinator.capture()
    let onMain = Self.reads.reads(rig.board)
    guard case .saved(let thought) = outcome else {
      Issue.record("expected a save, got \(outcome)")
      return
    }
    #expect(thought.content == .text("ls -la"))
    #expect(onMain.isEmpty)
  }

  @Test func acceptingAClipboardOfferReadsTheImageOffTheMainThread() async throws {
    let rig = try OfferCenterTests.rig(behavior: .ask)
    defer { rig.board.releaseGlobally() }
    rig.board.clearContents()
    rig.board.setData(try ListFixture.png(), forType: .png)
    rig.center.receive(.clipboard(changeCount: rig.board.changeCount, file: nil, at: Date()))
    await OfferCenterTests.wait(for: { rig.center.current != nil })
    Self.reads.watch(rig.board)
    let thought = try await rig.center.accept()
    let onMain = Self.reads.reads(rig.board)
    guard case .image = thought.content else {
      Issue.record("expected an image, got \(thought.content)")
      return
    }
    #expect(onMain.isEmpty)
  }

  @Test func theCopyKeyFallbackKeepsAndReadsTheClipboardOffTheMainThread() async {
    let board = PasteboardSnapshotTests.privateBoard()
    defer { board.releaseGlobally() }
    PasteboardSnapshotTests.fill(board)
    let before = PasteboardSnapshotTests.contents(of: board)
    let reader = SelectionReader(
      pasteboard: board,
      postCopy: {
        board.clearContents()
        board.setString("the selection", forType: .string)
      },
      secureInput: { false })
    Self.reads.watch(board)
    let (probe, _) = await reader.copySelection()
    let onMain = Self.reads.reads(board)
    #expect(probe == .text("the selection"))
    #expect(onMain.isEmpty)
    #expect(PasteboardSnapshotTests.contents(of: board) == before)
  }
}

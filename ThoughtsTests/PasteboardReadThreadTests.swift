import AppKit
import ObjectiveC
import Testing
import ThoughtsCore

@testable import Thoughts

final class MainThreadPasteboardReads: @unchecked Sendable {
  static let shared = MainThreadPasteboardReads()

  private typealias DataRead = @convention(c) (NSPasteboard, Selector, NSString) -> NSData?
  private typealias StringRead = @convention(c) (NSPasteboard, Selector, NSString) -> NSString?
  private typealias ObjectsRead =
    @convention(c) (NSPasteboard, Selector, NSArray, NSDictionary?) -> NSArray?
  private typealias ItemsRead = @convention(c) (NSPasteboard, Selector) -> NSArray?

  private let lock = NSLock()
  private var watched: Set<String> = []
  private var seen: [String: [String]] = [:]
  private var originals: [(method: Method, implementation: IMP)] = []
  private var arrivals: [String: @Sendable (NSPasteboard) -> Void] = [:]

  private init() {}

  func install() {
    lock.withLock {
      guard originals.isEmpty else { return }
      originals = [
        Self.replace(#selector(NSPasteboard.data(forType:))) { original, selector in
          let call = unsafeBitCast(original, to: DataRead.self)
          let read: @convention(block) (NSPasteboard, NSString) -> NSData? = { board, type in
            Self.shared.note(board, "data")
            return call(board, selector, type)
          }
          return imp_implementationWithBlock(read)
        },
        Self.replace(#selector(NSPasteboard.string(forType:))) { original, selector in
          let call = unsafeBitCast(original, to: StringRead.self)
          let read: @convention(block) (NSPasteboard, NSString) -> NSString? = { board, type in
            Self.shared.note(board, "string")
            return call(board, selector, type)
          }
          return imp_implementationWithBlock(read)
        },
        Self.replace(#selector(NSPasteboard.readObjects(forClasses:options:))) {
          original, selector in
          let call = unsafeBitCast(original, to: ObjectsRead.self)
          let read: @convention(block) (NSPasteboard, NSArray, NSDictionary?) -> NSArray? = {
            board, classes, options in
            Self.shared.note(board, "readObjects")
            return call(board, selector, classes, options)
          }
          return imp_implementationWithBlock(read)
        },
        Self.replace(#selector(getter: NSPasteboard.pasteboardItems)) { original, selector in
          let call = unsafeBitCast(original, to: ItemsRead.self)
          let read: @convention(block) (NSPasteboard) -> NSArray? = { board in
            Self.shared.note(board, "pasteboardItems")
            return call(board, selector)
          }
          return imp_implementationWithBlock(read)
        },
      ].compactMap { $0 }
    }
  }

  func uninstall() {
    lock.withLock {
      for original in originals {
        method_setImplementation(original.method, original.implementation)
      }
      originals = []
    }
  }

  private static func replace(_ selector: Selector, with make: (IMP, Selector) -> IMP) -> (
    method: Method, implementation: IMP
  )? {
    guard let method = class_getInstanceMethod(NSPasteboard.self, selector) else { return nil }
    let original = method_getImplementation(method)
    method_setImplementation(method, make(original, selector))
    return (method, original)
  }

  func watch(_ board: NSPasteboard) {
    lock.withLock { _ = watched.insert(board.name.rawValue) }
  }

  func arrive(on board: NSPasteboard, _ copy: @escaping @Sendable (NSPasteboard) -> Void) {
    lock.withLock { arrivals[board.name.rawValue] = copy }
  }

  func reads(_ board: NSPasteboard) -> [String] {
    lock.withLock {
      watched.remove(board.name.rawValue)
      arrivals[board.name.rawValue] = nil
      return seen.removeValue(forKey: board.name.rawValue) ?? []
    }
  }

  func note(_ board: NSPasteboard, _ call: String) {
    let name = board.name.rawValue
    let arrival = lock.withLock { arrivals.removeValue(forKey: name) }
    arrival?(board)
    guard Thread.isMainThread else { return }
    lock.withLock {
      guard watched.contains(name) else { return }
      seen[name, default: []].append(call)
    }
  }
}

struct RecordingMainThreadPasteboardReads: SuiteTrait, TestScoping {
  func provideScope(
    for test: Test, testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
    MainThreadPasteboardReads.shared.install()
    defer { MainThreadPasteboardReads.shared.uninstall() }
    try await function()
  }
}

extension SuiteTrait where Self == RecordingMainThreadPasteboardReads {
  static var recordingMainThreadPasteboardReads: Self { Self() }
}

@MainActor
@Suite(.recordingMainThreadPasteboardReads, .throwaway)
struct PasteboardReadThreadTests {
  static let reads = MainThreadPasteboardReads.shared

  @Test func theCaptureKeyReadsACopiedImageOffTheMainThread() async throws {
    let board = Throwaway.pasteboard()
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    let count = board.changeCount
    let fixture = try ListFixture()
    let reader = CaptureCoordinatorTests.FakeReader()
    reader.probeResult = .empty
    let defaults = try Throwaway.defaults()
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

  nonisolated static func passwordCopy(_ board: NSPasteboard) {
    board.clearContents()
    board.setString("hunter2", forType: .string)
    board.setData(Data(), forType: NSPasteboard.PasteboardType(ClipboardTypes.concealed))
  }

  @Test func aConcealedCopyLandingWhileTheCaptureKeyReadsIsNeverSaved() async throws {
    let rig = try CaptureCoordinatorTests.textRig(text: "ls -la")
    Self.reads.arrive(on: rig.board, Self.passwordCopy)
    let outcome = await rig.coordinator.capture()
    _ = Self.reads.reads(rig.board)
    #expect(outcome == .nothingToSave)
    #expect(try rig.fixture.store.entries().isEmpty)
  }

  @Test func aConcealedImageLandingWhileTheCaptureKeyReadsIsNeverSaved() async throws {
    let rig = try CaptureCoordinatorTests.textRig(text: nil, kind: .image)
    let png = try ListFixture.png()
    rig.board.setData(png, forType: .png)
    Self.reads.arrive(on: rig.board) { board in
      board.clearContents()
      board.setData(png, forType: .png)
      board.setData(Data(), forType: NSPasteboard.PasteboardType(ClipboardTypes.concealed))
    }
    let outcome = await rig.coordinator.capture()
    _ = Self.reads.reads(rig.board)
    #expect(outcome == .nothingToSave)
    #expect(try rig.fixture.store.entries().isEmpty)
  }

  @Test func aConcealedCopyLandingAfterTheCopyKeyIsNeverRead() async {
    let board = PasteboardSnapshotTests.privateBoard()
    PasteboardSnapshotTests.fill(board)
    let reader = SelectionReader(
      pasteboard: board,
      postCopy: {
        board.clearContents()
        board.setString("the selection", forType: .string)
        Self.reads.arrive(on: board, Self.passwordCopy)
      },
      secureInput: { false })
    let (probe, _) = await reader.copySelection()
    _ = Self.reads.reads(board)
    #expect(probe == .copiedNothing)
  }

  @Test func aConcealedCopyLandingBeforeTheCopyKeyStopsTheFallback() async {
    let board = PasteboardSnapshotTests.privateBoard()
    PasteboardSnapshotTests.fill(board)
    let log = CallLog()
    let reader = SelectionReader(
      pasteboard: board, postCopy: { log.add("copy") }, secureInput: { false })
    Self.reads.arrive(on: board, Self.passwordCopy)
    let (probe, counts) = await reader.copySelection()
    _ = Self.reads.reads(board)
    #expect(probe == .copiedNothing)
    #expect(counts.isEmpty)
    #expect(log.events.isEmpty)
  }
}

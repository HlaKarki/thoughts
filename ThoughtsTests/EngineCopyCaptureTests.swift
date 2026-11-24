import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized)
struct EngineCopyCaptureTests {
  static let browser = AppSnapshot(pid: 51, bundleID: "dev.example.browser", name: "Browser")
  static let browserSource = Source(app: "Browser", bundleID: "dev.example.browser")
  static let words = "copied words"
  static let smartPaste = NSPasteboard.PasteboardType(
    "dyn.ah62d4rv4gu8y63n2nuuhg5pbsm4ca6dbsr4gnkduqf31k3pcr7u1e3basv61a3k")
  static let frameToken = NSPasteboard.PasteboardType("org.chromium.internal.source-rfh-token")
  static let sourceURL = NSPasteboard.PasteboardType("org.chromium.source-url")
  static let concealed = NSPasteboard.PasteboardType(ClipboardTypes.concealed)

  enum Copy {
    case selection
    case writeText
    case password
  }

  static func write(_ copy: Copy, to board: NSPasteboard) {
    board.prepareForNewContents(with: [])
    if copy == .password { board.setData(nil, forType: concealed) }
    if copy == .selection {
      board.setString("<meta charset='utf-8'><p>\(words)</p>", forType: .html)
    }
    board.setString(words, forType: .string)
    if copy == .selection { board.setData(nil, forType: smartPaste) }
    board.setData(Data([1, 2, 3, 4]), forType: frameToken)
    board.setString("https://example.com/page", forType: sourceURL)
  }

  @MainActor
  final class Rig {
    let fixture: ListFixture
    let board: NSPasteboard
    let reader: CaptureCoordinatorTests.FakeReader
    let writer: PasteboardWriter
    let watcher: ClipboardWatcher
    let coordinator: CaptureCoordinator
    let suite: String

    init(
      behavior: NSPasteboard.AccessBehavior = .alwaysAllow, ownWindowIsKey: Bool = false,
      captureDelay: TimeInterval = 0
    ) throws {
      let fixture = try ListFixture()
      let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
      let suite = "thoughts.tests.\(UUID().uuidString)"
      let defaults = try #require(UserDefaults(suiteName: suite))
      let reader = CaptureCoordinatorTests.FakeReader()
      let writer = PasteboardWriter(pasteboard: board)
      let watcher = ClipboardWatcher(
        pasteboard: board, accessBehavior: { behavior },
        isOwnChange: { writer.ownChangeCounts.contains($0) }, contentType: { nil },
        now: { ListFixture.now }, frontmost: { EngineCopyCaptureTests.browser },
        ownWindowIsKey: { ownWindowIsKey })
      coordinator = CaptureCoordinator(
        frontmost: { EngineCopyCaptureTests.browser }, ownBundleID: "dev.example.thoughts",
        ownWindowIsKey: { false }, reader: reader,
        source: { EngineCopyCaptureTests.browserSource }, input: fixture.input, writer: writer,
        sound: SavedSound(preferences: Preferences(defaults: defaults), player: {}),
        pasteboard: board, now: { ListFixture.now.addingTimeInterval(captureDelay) },
        clipboardCopy: { watcher.lastCopy }, accessBehavior: { behavior })
      self.fixture = fixture
      self.board = board
      self.suite = suite
      self.reader = reader
      self.writer = writer
      self.watcher = watcher
    }

    func copy(_ copy: Copy) {
      EngineCopyCaptureTests.write(copy, to: board)
    }

    func poll() async {
      watcher.poll()
      var waits = 0
      while watcher.lastCopy?.changeCount != board.changeCount, waits < 100 {
        waits += 1
        try? await Task.sleep(for: .milliseconds(10))
      }
    }

    var storedTexts: [String] {
      get throws {
        try fixture.store.entries().compactMap(\.thought).compactMap {
          if case .text(let text) = $0.content { return text }
          return nil
        }
      }
    }

    func close() {
      board.releaseGlobally()
      UserDefaults().removePersistentDomain(forName: suite)
    }
  }

  @Test func theEngineMarksOnlyPasswordCopiesWithAnExcludedType() {
    for (copy, excluded) in [(Copy.selection, false), (.writeText, false), (.password, true)] {
      let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
      defer { board.releaseGlobally() }
      Self.write(copy, to: board)
      #expect(ClipboardWatcher.isExcluded(board.types ?? []) == excluded)
    }
  }

  @Test func aPolledEngineCopyIsKeptInEveryAccessMode() async throws {
    for (behavior, kind) in [
      (NSPasteboard.AccessBehavior.alwaysAllow, ClipboardCopy.Kind.text), (.ask, .unknown),
      (.default, .unknown),
    ] {
      for copy in [Copy.selection, .writeText] {
        let rig = try Rig(behavior: behavior)
        defer { rig.close() }
        rig.copy(copy)
        await rig.poll()
        #expect(rig.watcher.lastCopy?.kind == kind)
        #expect(rig.watcher.lastCopy?.changeCount == rig.board.changeCount)
      }
    }
  }

  @Test func aSelectionTheAccessibilityReadAnswersIsSaved() async throws {
    let rig = try Rig()
    defer { rig.close() }
    rig.copy(.selection)
    await rig.poll()
    rig.reader.probeResult = .text(Self.words)
    guard case .saved = await rig.coordinator.capture() else {
      Issue.record("expected a save")
      return
    }
    #expect(try rig.storedTexts == [Self.words])
    #expect(rig.reader.copies == 0)
  }

  @Test func aPageCopyWithNoSelectionLeftIsSavedFromTheClipboard() async throws {
    for probe in [SelectionProbe.unavailable, .copyDisabled] {
      let rig = try Rig()
      defer { rig.close() }
      rig.copy(.writeText)
      await rig.poll()
      rig.reader.probeResult = probe
      rig.reader.copyResult = .copiedNothing
      guard case .saved = await rig.coordinator.capture() else {
        Issue.record("expected a save after \(probe)")
        continue
      }
      #expect(try rig.storedTexts == [Self.words])
      #expect(rig.reader.copies == (probe == .unavailable ? 1 : 0))
    }
  }

  @Test func secureInputHeldByAnyAppSaysNothingToSaveOverAFreshCopy() async throws {
    #expect(AXReader(secureInput: { true }).selection(pid: 0) == .secureField)
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    final class Posts { var count = 0 }
    let posts = Posts()
    let reader = SelectionReader(
      pasteboard: board, postCopy: { posts.count += 1 }, secureInput: { true })
    let (copied, counts) = await reader.copySelection()
    #expect(copied == .secureField)
    #expect(counts.isEmpty)
    #expect(posts.count == 0)

    for copy in [Copy.selection, .writeText] {
      let rig = try Rig()
      defer { rig.close() }
      rig.copy(copy)
      await rig.poll()
      #expect(rig.watcher.lastCopy?.kind == .text)
      rig.reader.probeResult = .secureField
      #expect(await rig.coordinator.capture() == .nothingToSave)
      #expect(try rig.storedTexts.isEmpty)
      #expect(rig.reader.copies == 0)
    }
  }

  @Test func aCopyTheWatcherHasNotPolledYetSaysNothingToSave() async throws {
    let rig = try Rig()
    defer { rig.close() }
    rig.copy(.writeText)
    rig.reader.probeResult = .unavailable
    rig.reader.copyResult = .copiedNothing
    #expect(rig.watcher.lastCopy == nil)
    #expect(await rig.coordinator.capture() == .nothingToSave)
    await rig.poll()
    guard case .saved = await rig.coordinator.capture() else {
      Issue.record("expected a save once the watcher polled")
      return
    }
    #expect(try rig.storedTexts == [Self.words])
  }

  @Test func aCopyPolledWhileAThoughtsWindowWasKeyCountsAsOwn() async throws {
    let rig = try Rig(ownWindowIsKey: true)
    defer { rig.close() }
    rig.copy(.writeText)
    await rig.poll()
    #expect(rig.watcher.lastCopy?.own == true)
    rig.reader.probeResult = .unavailable
    rig.reader.copyResult = .copiedNothing
    #expect(await rig.coordinator.capture() == .nothingToSave)
  }

  @Test func aCopyOlderThanTwoMinutesSaysNothingToSave() async throws {
    let rig = try Rig(captureDelay: CaptureDecision.imageWindow + 1)
    defer { rig.close() }
    rig.copy(.writeText)
    await rig.poll()
    rig.reader.probeResult = .unavailable
    rig.reader.copyResult = .copiedNothing
    #expect(await rig.coordinator.capture() == .nothingToSave)
  }

  @Test func aPasswordCopyFromTheEngineIsNeverKept() async throws {
    let rig = try Rig()
    defer { rig.close() }
    rig.copy(.password)
    await rig.poll()
    #expect(rig.watcher.lastCopy == nil)
    rig.reader.probeResult = .unavailable
    rig.reader.copyResult = .copiedNothing
    #expect(await rig.coordinator.capture() == .nothingToSave)
  }
}

import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized)
struct EngineCopyCaptureTests {
  static let browser = AppSnapshot(pid: 51, bundleID: "dev.example.browser", name: "Browser")
  static let hostInFront = AppSnapshot(
    pid: ProcessInfo.processInfo.processIdentifier, bundleID: "dev.example.browser",
    name: "Browser")
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

  static func isSaved(_ outcome: CaptureOutcome) -> Bool {
    if case .saved = outcome { true } else { false }
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
      captureDelay: TimeInterval = 0, front: AppSnapshot = EngineCopyCaptureTests.browser,
      selectionReader: (@MainActor (NSPasteboard) -> any SelectionReading)? = nil
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
        now: { ListFixture.now }, frontmost: { front }, ownWindowIsKey: { ownWindowIsKey })
      coordinator = CaptureCoordinator(
        frontmost: { front }, ownBundleID: "dev.example.thoughts",
        ownWindowIsKey: { false }, reader: selectionReader?(board) ?? reader,
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

  @Test func aFreshCopyIsSavedWhileAnotherProcessHoldsSecureInputAndNothingIsSelected()
    async throws
  {
    let axReader = AXReader(secureInput: { true })
    for copy in [Copy.selection, .writeText] {
      let rig = try Rig(front: Self.hostInFront) { board in
        SelectionReader(
          pasteboard: board, readSelection: { axReader.selection(pid: $0) }, postCopy: {},
          secureInput: { true })
      }
      defer { rig.close() }
      rig.copy(copy)
      await rig.poll()
      #expect(rig.watcher.lastCopy?.kind == .text)
      let outcome = await rig.coordinator.capture()
      let stored = try rig.storedTexts
      withKnownIssue("Secure input held by any process reads as a secure field in the front app") {
        #expect(Self.isSaved(outcome), "got \(outcome)")
        #expect(stored == [Self.words])
      }
    }
  }

  @Test func aCopyTheWatcherHasNotPolledYetIsSaved() async throws {
    let rig = try Rig()
    defer { rig.close() }
    rig.copy(.writeText)
    rig.reader.probeResult = .unavailable
    rig.reader.copyResult = .copiedNothing
    #expect(rig.watcher.lastCopy == nil)
    let outcome = await rig.coordinator.capture()
    let stored = try rig.storedTexts
    withKnownIssue("The capture reads only the copy the watcher last polled") {
      #expect(Self.isSaved(outcome), "got \(outcome)")
      #expect(stored == [Self.words])
    }
  }

  @Test func aCopyMadeInAnotherAppWhileAThoughtsWindowIsKeyIsSaved() async throws {
    let rig = try Rig(ownWindowIsKey: true)
    defer { rig.close() }
    rig.copy(.writeText)
    await rig.poll()
    rig.reader.probeResult = .unavailable
    rig.reader.copyResult = .copiedNothing
    let own = rig.watcher.lastCopy?.own
    let outcome = await rig.coordinator.capture()
    let stored = try rig.storedTexts
    withKnownIssue("The watcher marks every copy polled while a Thoughts window is key as its own")
    {
      #expect(own == false)
      #expect(Self.isSaved(outcome), "got \(outcome)")
      #expect(stored == [Self.words])
    }
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

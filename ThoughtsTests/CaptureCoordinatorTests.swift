import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.throwaway)
struct CaptureCoordinatorTests {
  static let own = "dev.example.thoughts"
  static let notes = AppSnapshot(pid: 41, bundleID: "com.apple.Notes", name: "Notes")
  static let editor = AppSnapshot(pid: 42, bundleID: "com.microsoft.VSCode", name: "Code")
  static let page = Source(app: "Notes", bundleID: "com.apple.Notes")

  @MainActor
  final class FakeReader: SelectionReading {
    var secureInputOn = false
    var probed: [Int32] = []
    var copies = 0
    var probeResult = SelectionProbe.unavailable
    var copyResult = SelectionProbe.copiedNothing
    var copyCounts: [Int] = []
    var onCopy: @MainActor () -> Void = {}

    func probe(pid: Int32) async -> SelectionProbe {
      probed.append(pid)
      return probeResult
    }

    func copySelection() async -> (SelectionProbe, ownChangeCounts: [Int]) {
      copies += 1
      onCopy()
      return (copyResult, copyCounts)
    }
  }

  struct Rig {
    let fixture: ListFixture
    let board: NSPasteboard
    let reader: FakeReader
    let writer: PasteboardWriter
    let coordinator: CaptureCoordinator
    let plays: Plays
    let defaults: UserDefaults
  }

  @MainActor
  final class Plays {
    var count = 0
  }

  static func rig(
    front: AppSnapshot? = notes,
    ownWindowIsKey: Bool = false,
    soundEnabled: Bool = true,
    image: (() -> ClipboardCopy?)? = nil,
    offer: OfferID? = nil,
    accept: (() async throws -> Thought)? = nil
  ) throws -> Rig {
    let fixture = try ListFixture()
    let board = Throwaway.pasteboard()
    let defaults = try Throwaway.defaults()
    let preferences = Preferences(defaults: defaults)
    preferences.soundEnabled = soundEnabled
    let plays = Plays()
    let reader = FakeReader()
    let writer = PasteboardWriter(pasteboard: board)
    let coordinator = CaptureCoordinator(
      frontmost: { front }, ownBundleID: own, ownWindowIsKey: { ownWindowIsKey }, reader: reader,
      source: { page },
      input: fixture.input, writer: writer,
      sound: SavedSound(preferences: preferences, player: { plays.count += 1 }),
      pasteboard: board, now: { ListFixture.now },
      currentOffer: offer.map { id in { id } }, acceptOffer: accept, clipboardCopy: image)
    return Rig(
      fixture: fixture, board: board, reader: reader, writer: writer, coordinator: coordinator,
      plays: plays, defaults: defaults)
  }

  @Test func selectedTextIsSavedWithItsSourceAndPlaysTheSound() async throws {
    let rig = try Self.rig()
    rig.reader.probeResult = .text("  keep this line \n")
    var saves: [ManualSave] = []
    rig.fixture.input.onManualSave = { saves.append($0) }
    let outcome = await rig.coordinator.capture()
    guard case .saved(let thought) = outcome else {
      Issue.record("expected a save, got \(outcome)")
      return
    }
    #expect(thought.content == .text("keep this line"))
    #expect(thought.source == Self.page)
    #expect(try rig.fixture.store.entries().compactMap(\.thought).count == 1)
    #expect(rig.reader.probed == [Self.notes.pid])
    #expect(rig.reader.copies == 0)
    #expect(rig.plays.count == 1)
    #expect(saves.map(\.file) == [thought.file])
  }

  @Test func soundOffStaysSilent() async throws {
    let rig = try Self.rig(soundEnabled: false)
    rig.reader.probeResult = .text("quiet")
    _ = await rig.coordinator.capture()
    #expect(rig.plays.count == 0)
  }

  @Test func unavailableSelectionCopiesAndNotesBothChangeCounts() async throws {
    let rig = try Self.rig()
    rig.reader.probeResult = .unavailable
    rig.reader.copyResult = .text("copied words")
    rig.reader.copyCounts = [11, 12]
    let outcome = await rig.coordinator.capture()
    guard case .saved(let thought) = outcome else {
      Issue.record("expected a save, got \(outcome)")
      return
    }
    #expect(thought.content == .text("copied words"))
    #expect(rig.reader.copies == 1)
    #expect(rig.writer.ownChangeCounts == [11, 12])
  }

  @Test func anAppWithNothingToCopyNeverGetsTheCopyKey() async throws {
    for probe in [SelectionProbe.empty, .copyDisabled] {
      let rig = try Self.rig()
      rig.reader.probeResult = probe
      #expect(await rig.coordinator.capture() == .nothingToSave)
      #expect(rig.reader.copies == 0)
      #expect(rig.plays.count == 0)
    }
  }

  @Test func anAppThatGivesNoEvidenceStillGetsTheCopyKey() async throws {
    let rig = try Self.rig()
    rig.reader.probeResult = .unavailable
    rig.reader.copyResult = .text("from a silent app")
    guard case .saved(let thought) = await rig.coordinator.capture() else {
      Issue.record("expected a save")
      return
    }
    #expect(thought.content == .text("from a silent app"))
    #expect(rig.reader.copies == 1)
  }

  @Test func emptyAnswerInAnEditorThatCopiesALineSavesNothing() async throws {
    let rig = try Self.rig(front: Self.editor)
    rig.reader.probeResult = .empty
    let outcome = await rig.coordinator.capture()
    #expect(outcome == .nothingToSave)
    #expect(rig.reader.copies == 0)
    #expect(rig.plays.count == 0)
    #expect(try rig.fixture.store.entries().isEmpty)
  }

  @Test func ownWindowBeingKeyNeverProbesOrCopiesFromTheAppBehindIt() async throws {
    let rig = try Self.rig(front: Self.notes, ownWindowIsKey: true)
    rig.reader.probeResult = .text("text in the app behind")
    rig.reader.copyResult = .text("copied from the app behind")
    let outcome = await rig.coordinator.capture()
    #expect(outcome == .nothingToSave)
    #expect(rig.reader.probed.isEmpty)
    #expect(rig.reader.copies == 0)
  }

  @Test func recentClipboardImageIsSavedAndReportsItsChangeCount() async throws {
    let board = Throwaway.pasteboard()
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    let seen = ListFixture.now.addingTimeInterval(-30)
    let count = board.changeCount
    let fixture = try ListFixture()
    let reader = FakeReader()
    reader.probeResult = .empty
    let defaults = try Throwaway.defaults()
    let coordinator = CaptureCoordinator(
      frontmost: { Self.editor }, ownBundleID: Self.own, ownWindowIsKey: { false }, reader: reader,
      source: { Self.page },
      input: fixture.input, writer: PasteboardWriter(pasteboard: board),
      sound: SavedSound(preferences: Preferences(defaults: defaults), player: {}),
      pasteboard: board, now: { ListFixture.now },
      clipboardCopy: { ClipboardCopy(changeCount: count, seen: seen, kind: .image) })
    var saves: [ManualSave] = []
    fixture.input.onManualSave = { saves.append($0) }
    let outcome = await coordinator.capture()
    guard case .saved(let thought) = outcome, case .image = thought.content else {
      Issue.record("expected an image, got \(outcome)")
      return
    }
    #expect(saves.first?.pasteboardChangeCount == count)
  }

  @Test func aCopiedImageFileRecordsItsPathAsTheSourceFile() async throws {
    let rig = try Self.imageRig()
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("cat.png")
    try ListFixture.png().write(to: file)
    rig.board.clearContents()
    rig.board.writeObjects([file as NSURL])
    let count = rig.board.changeCount
    let coordinator = CaptureCoordinator(
      frontmost: { Self.editor }, ownBundleID: Self.own, ownWindowIsKey: { false },
      reader: rig.reader, source: { Self.page }, input: rig.fixture.input,
      writer: PasteboardWriter(pasteboard: rig.board),
      sound: SavedSound(
        preferences: Preferences(
          defaults: try Throwaway.defaults()),
        player: {}),
      pasteboard: rig.board, now: { ListFixture.now },
      clipboardCopy: {
        ClipboardCopy(
          changeCount: count, seen: ListFixture.now.addingTimeInterval(-30), kind: .image)
      })
    guard case .saved(let thought) = await coordinator.capture() else {
      Issue.record("expected a save")
      return
    }
    #expect(thought.source?.file == file.path)
    #expect(thought.source?.app == Self.page.app)
  }

  static func imageRig(
    probe: SelectionProbe = .empty, front: AppSnapshot? = editor
  ) throws -> (
    fixture: ListFixture, board: NSPasteboard, reader: FakeReader, coordinator: CaptureCoordinator,
    count: Int
  ) {
    let board = Throwaway.pasteboard()
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    let count = board.changeCount
    let fixture = try ListFixture()
    let reader = FakeReader()
    reader.probeResult = probe
    let defaults = try Throwaway.defaults()
    let coordinator = CaptureCoordinator(
      frontmost: { front }, ownBundleID: own, ownWindowIsKey: { false }, reader: reader,
      source: { page }, input: fixture.input, writer: PasteboardWriter(pasteboard: board),
      sound: SavedSound(preferences: Preferences(defaults: defaults), player: {}),
      pasteboard: board, now: { ListFixture.now },
      clipboardCopy: {
        ClipboardCopy(
          changeCount: board.changeCount, seen: ListFixture.now.addingTimeInterval(-30),
          kind: .image)
      })
    return (fixture, board, reader, coordinator, count)
  }

  @Test func shiftShiftTwiceOnOneImageCopySavesItOnce() async throws {
    let rig = try Self.imageRig()
    guard case .saved(let first) = await rig.coordinator.capture() else {
      Issue.record("expected the first press to save")
      return
    }
    #expect(await rig.coordinator.capture() == .alreadySaved(first))
    #expect(await rig.coordinator.capture() == .alreadySaved(first))
    #expect(try rig.fixture.store.entries().compactMap(\.thought).count == 1)
  }

  @Test func theImageSavesAgainAfterItsThoughtIsDeletedOrTheImageIsCopiedAgain() async throws {
    let rig = try Self.imageRig()
    guard case .saved(let first) = await rig.coordinator.capture() else {
      Issue.record("expected the first press to save")
      return
    }
    try FileManager.default.removeItem(at: first.file)
    guard case .saved = await rig.coordinator.capture() else {
      Issue.record("expected a save after the delete")
      return
    }
    rig.board.clearContents()
    rig.board.setData(try ListFixture.png(), forType: .png)
    guard case .saved = await rig.coordinator.capture() else {
      Issue.record("expected a save for a new copy")
      return
    }
    #expect(try rig.fixture.store.entries().compactMap(\.thought).count == 2)
  }

  @Test func theCopyRoundTripOfAnAppWithNoSelectionAnswerDoesNotSaveTheImageTwice() async throws {
    let rig = try Self.imageRig(probe: .unavailable, front: Self.notes)
    let png = try ListFixture.png()
    rig.reader.onCopy = {
      rig.board.clearContents()
      rig.board.setData(png, forType: .png)
    }
    guard case .saved(let first) = await rig.coordinator.capture() else {
      Issue.record("expected the first press to save")
      return
    }
    #expect(rig.board.changeCount != rig.count)
    #expect(await rig.coordinator.capture() == .alreadySaved(first))
    #expect(rig.reader.copies == 2)
    #expect(try rig.fixture.store.entries().compactMap(\.thought).count == 1)
  }

  @Test func anImageKeptThroughTheOfferIsAlreadySavedForShiftShift() async throws {
    let rig = try Self.imageRig()
    let defaults = try Throwaway.defaults()
    let temp = TempFolder()
    let preferences = Preferences(defaults: defaults)
    let center = OfferCenter(
      preferences: preferences, input: rig.fixture.input,
      clipboard: ClipboardWatcher(pasteboard: rig.board, accessBehavior: { .ask }),
      screenshots: ScreenshotFolderWatcher(storageFolder: { rig.fixture.folder }),
      sound: SavedSound(preferences: preferences, player: {}), source: { Self.page },
      pasteboard: rig.board, location: ScreenshotLocation(defaults: nil, home: temp.url),
      accessBehavior: { .ask })
    center.receive(.clipboard(changeCount: rig.count, file: nil, at: Date()))
    await OfferCenterTests.wait { center.current != nil }
    let kept = try await center.accept()
    #expect(await rig.coordinator.capture() == .alreadySaved(kept))
    #expect(try rig.fixture.store.entries().compactMap(\.thought).count == 1)
  }

  @Test func shiftShiftTwiceOnOneSelectionSavesOneThought() async throws {
    let rig = try Self.rig()
    rig.reader.probeResult = .text("buy oat milk")
    guard case .saved(let first) = await rig.coordinator.capture() else {
      Issue.record("expected the first press to save")
      return
    }
    #expect(await rig.coordinator.capture() == .alreadySaved(first))
    #expect(rig.plays.count == 1)
    #expect(try rig.fixture.store.entries().compactMap(\.thought).count == 1)
    rig.reader.probeResult = .text("buy eggs")
    guard case .saved = await rig.coordinator.capture() else {
      Issue.record("expected a different text to save")
      return
    }
  }

  @Test func theSameTextSavesAgainAfterTheOwnerDeletesIt() async throws {
    let rig = try Self.rig()
    rig.reader.probeResult = .text("buy oat milk")
    guard case .saved(let first) = await rig.coordinator.capture() else {
      Issue.record("expected the first press to save")
      return
    }
    try FileManager.default.removeItem(at: first.file)
    guard case .saved = await rig.coordinator.capture() else {
      Issue.record("expected a save after the delete")
      return
    }
  }

  static let terminal = AppSnapshot(pid: 43, bundleID: "dev.example.terminal", name: "Terminal")
  static let terminalSource = Source(app: "Terminal", bundleID: "dev.example.terminal")

  static func textRig(
    probe: SelectionProbe = .empty, front: AppSnapshot? = editor, text: String? = "ls -la",
    age: TimeInterval = 60, kind: ClipboardCopy.Kind = .text, own: Bool = false,
    recorded: Source = page, access: NSPasteboard.AccessBehavior = .alwaysAllow
  ) throws -> (
    fixture: ListFixture, board: NSPasteboard, reader: FakeReader, coordinator: CaptureCoordinator
  ) {
    let board = Throwaway.pasteboard()
    board.clearContents()
    if let text { board.setString(text, forType: .string) }
    let fixture = try ListFixture()
    let reader = FakeReader()
    reader.probeResult = probe
    let defaults = try Throwaway.defaults()
    let coordinator = CaptureCoordinator(
      frontmost: { front }, ownBundleID: Self.own, ownWindowIsKey: { false },
      reader: reader, source: { recorded }, input: fixture.input,
      writer: PasteboardWriter(pasteboard: board),
      sound: SavedSound(preferences: Preferences(defaults: defaults), player: {}),
      pasteboard: board, now: { ListFixture.now },
      clipboardCopy: {
        ClipboardCopy(
          changeCount: board.changeCount, seen: ListFixture.now.addingTimeInterval(-age),
          kind: kind, app: terminal, own: own)
      },
      accessBehavior: { access })
    return (fixture, board, reader, coordinator)
  }

  @Test func textCopiedAMinuteAgoIsSavedWithTheAppThatCopiedIt() async throws {
    let rig = try Self.textRig(text: "  ls -la\n")
    var saves: [ManualSave] = []
    rig.fixture.input.onManualSave = { saves.append($0) }
    guard case .saved(let thought) = await rig.coordinator.capture() else {
      Issue.record("expected a save")
      return
    }
    #expect(thought.content == .text("ls -la"))
    #expect(thought.source == Self.terminalSource)
    #expect(saves.first?.pasteboardChangeCount == rig.board.changeCount)
  }

  @Test func textCopiedFromTheAppStillInFrontKeepsItsWindowAndPage() async throws {
    let frontSource = Source(
      app: "Terminal", bundleID: "dev.example.terminal", window: "~/code", title: "~/code")
    let rig = try Self.textRig(front: Self.terminal, recorded: frontSource)
    guard case .saved(let thought) = await rig.coordinator.capture() else {
      Issue.record("expected a save")
      return
    }
    #expect(thought.source == frontSource)
  }

  @Test func textCopiedThreeMinutesAgoSavesNothing() async throws {
    let rig = try Self.textRig(age: 180)
    #expect(await rig.coordinator.capture() == .nothingToSave)
    #expect(try rig.fixture.store.entries().isEmpty)
  }

  @Test func shiftShiftTwiceOnOneTextCopySavesOneThought() async throws {
    let rig = try Self.textRig()
    guard case .saved(let first) = await rig.coordinator.capture() else {
      Issue.record("expected the first press to save")
      return
    }
    #expect(await rig.coordinator.capture() == .alreadySaved(first))
    #expect(try rig.fixture.store.entries().compactMap(\.thought).count == 1)
  }

  @Test func aNewCopyOfTheSameTextFromTheSameAppIsAlreadySaved() async throws {
    let rig = try Self.textRig()
    guard case .saved(let first) = await rig.coordinator.capture() else {
      Issue.record("expected the first press to save")
      return
    }
    rig.board.clearContents()
    rig.board.setString("ls -la", forType: .string)
    #expect(await rig.coordinator.capture() == .alreadySaved(first))
    #expect(try rig.fixture.store.entries().compactMap(\.thought).count == 1)
  }

  @Test func theTextCopySavesAgainAfterTheOwnerDeletesIt() async throws {
    let rig = try Self.textRig()
    guard case .saved(let first) = await rig.coordinator.capture() else {
      Issue.record("expected the first press to save")
      return
    }
    try FileManager.default.removeItem(at: first.file)
    guard case .saved = await rig.coordinator.capture() else {
      Issue.record("expected a save after the delete")
      return
    }
  }

  @Test func anAppWithNoSelectionAnswerFallsThroughTheCopyKeyToTheRecentTextCopy() async throws {
    let rig = try Self.textRig(probe: .unavailable, front: Self.notes)
    guard case .saved(let thought) = await rig.coordinator.capture() else {
      Issue.record("expected a save")
      return
    }
    #expect(rig.reader.copies == 1)
    #expect(thought.content == .text("ls -la"))
  }

  @Test func aSelectionBeatsARecentTextCopy() async throws {
    let rig = try Self.textRig(probe: .text("selected words"))
    guard case .saved(let thought) = await rig.coordinator.capture() else {
      Issue.record("expected a save")
      return
    }
    #expect(thought.content == .text("selected words"))
  }

  @Test func anImageBeatsTextWhenOneCopyHoldsBoth() async throws {
    let rig = try Self.textRig(kind: .unknown)
    rig.board.setData(try ListFixture.png(), forType: .png)
    guard case .saved(let thought) = await rig.coordinator.capture(), case .image = thought.content
    else {
      Issue.record("expected an image")
      return
    }
  }

  @Test func textThoughtsCopiedItselfNeverSaves() async throws {
    let rig = try Self.textRig(own: true)
    #expect(await rig.coordinator.capture() == .nothingToSave)
    let unknown = try Self.textRig(kind: .unknown, own: true)
    #expect(await unknown.coordinator.capture() == .nothingToSave)
    #expect(try rig.fixture.store.entries().isEmpty)
  }

  @Test func aFinderCopyOfAFileNeverSavesAsText() async throws {
    let rig = try Self.textRig(text: nil, kind: .unknown)
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("notes.txt")
    try Data([1]).write(to: file)
    rig.board.clearContents()
    rig.board.writeObjects([file as NSURL])
    rig.board.setString("notes.txt", forType: .string)
    #expect(await rig.coordinator.capture() == .nothingToSave)
    #expect(try rig.fixture.store.entries().isEmpty)
  }

  @Test(arguments: [ClipboardCopy.Kind.text, .unknown, .image])
  func aCopyMarkedConcealedNeverSaves(_ kind: ClipboardCopy.Kind) async throws {
    let rig = try Self.textRig(text: "hunter2", kind: kind)
    rig.board.setData(try ListFixture.png(), forType: .png)
    rig.board.setData(Data(), forType: NSPasteboard.PasteboardType(ClipboardTypes.concealed))
    #expect(await rig.coordinator.capture() == .nothingToSave)
    #expect(try rig.fixture.store.entries().isEmpty)
  }

  static let refused = CaptureOutcome.failed(CaptureCoordinator.pasteRefusedMessage)

  @Test(arguments: [ClipboardCopy.Kind.text, .unknown])
  func aRefusedPasteOfARecentCopyIsCouldntSaveNotNothingToSave(_ kind: ClipboardCopy.Kind)
    async throws
  {
    for access in [NSPasteboard.AccessBehavior.ask, .alwaysDeny] {
      let rig = try Self.textRig(text: nil, kind: kind, access: access)
      #expect(await rig.coordinator.capture() == Self.refused)
      #expect(try rig.fixture.store.entries().isEmpty)
    }
  }

  @Test func aRefusedPasteOfARecentImageIsCouldntSaveToo() async throws {
    let rig = try Self.textRig(text: nil, kind: .image, access: .alwaysDeny)
    #expect(await rig.coordinator.capture() == Self.refused)
  }

  @Test func anEmptyReadWithPasteAllowedIsStillNothingToSave() async throws {
    let rig = try Self.textRig(text: nil, kind: .unknown, access: .alwaysAllow)
    #expect(await rig.coordinator.capture() == .nothingToSave)
    let image = try Self.textRig(text: nil, kind: .image, access: .alwaysAllow)
    #expect(await image.coordinator.capture() == .nothingToSave)
  }

  @Test func anEmptyOrBlankClipboardSavesNothing() async throws {
    for text in [nil, "  \n"] {
      let rig = try Self.textRig(text: text, kind: .unknown)
      #expect(await rig.coordinator.capture() == .nothingToSave)
    }
  }

  @Test func aNonImageFileOnTheClipboardIsNotSavedAsItsIcon() throws {
    let board = Throwaway.pasteboard()
    let folder = TempFolder()
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent("report.pdf")
    try Data([1]).write(to: file)
    board.clearContents()
    board.writeObjects([file as NSURL])
    board.addTypes([.tiff], owner: nil)
    board.setData(try ListFixture.tiff(), forType: .tiff)
    #expect(CaptureCoordinator.image(in: board) == nil)
  }

  @Test func staleClipboardImageSavesNothing() async throws {
    let rig = try Self.rig(
      front: Self.editor,
      image: { ClipboardCopy(changeCount: -1, seen: ListFixture.now, kind: .image) })
    rig.reader.probeResult = .empty
    #expect(await rig.coordinator.capture() == .nothingToSave)
  }

  @Test func offerIsAcceptedBeforeAnySelectionIsRead() async throws {
    let fixture = try ListFixture()
    let thought = try fixture.addText("From the offer", daysAgo: 0)
    let rig = try Self.rig(offer: OfferID(), accept: { thought })
    let outcome = await rig.coordinator.capture()
    #expect(outcome == .acceptedOffer(thought))
    #expect(rig.reader.probed.isEmpty)
    #expect(rig.plays.count == 0)
  }

  @Test func failedOfferShowsItsMessage() async throws {
    let rig = try Self.rig(
      offer: OfferID(), accept: { throw ThoughtsError.clipboardChanged })
    #expect(
      await rig.coordinator.capture()
        == .failed(ListModel.message(for: ThoughtsError.clipboardChanged)))
  }
}

@MainActor
@Suite(.throwaway)
struct GesturePreferencesTests {
  @Test func gestureStartsOnShiftAndSoundOnThenBothPersist() throws {
    let defaults = try Throwaway.defaults()
    let preferences = Preferences(defaults: defaults)
    #expect(preferences.gesture == .shift)
    #expect(preferences.soundEnabled)
    preferences.gesture = nil
    preferences.soundEnabled = false
    #expect(Preferences(defaults: defaults).gesture == nil)
    #expect(!Preferences(defaults: defaults).soundEnabled)
    preferences.gesture = .option
    #expect(Preferences(defaults: defaults).gesture == .option)
  }

  @Test func eventFlagsMapToModifiers() {
    #expect(GestureMonitor.modifiers(from: [.shift, .capsLock]) == [.shift])
    #expect(GestureMonitor.modifiers(from: [.command, .option]) == [.command, .option])
    #expect(GestureMonitor.event(type: .keyDown, flags: [], at: 3) == .key(at: 3))
    #expect(
      GestureMonitor.event(type: .flagsChanged, flags: [.shift], at: 1)
        == .modifiers([.shift], at: 1))
    #expect(GestureMonitor.event(type: .scrollWheel, flags: [], at: 1) == nil)
  }

  @Test func shiftClicksDoNotFireTheGesture() {
    for button in [NSEvent.EventType.leftMouseDown, .rightMouseDown, .otherMouseDown] {
      var detector = DoubleTapDetector(modifier: .shift)
      let events: [(NSEvent.EventType, NSEvent.ModifierFlags, TimeInterval)] = [
        (.flagsChanged, [.shift], 0), (button, [.shift], 0.05), (.flagsChanged, [], 0.10),
        (.flagsChanged, [.shift], 0.30), (button, [.shift], 0.33), (.flagsChanged, [], 0.38),
      ]
      let fired = events.compactMap { GestureMonitor.event(type: $0.0, flags: $0.1, at: $0.2) }
        .map { detector.feed($0) }
      #expect(!fired.contains(true), "\(button.rawValue)")
    }
  }
}

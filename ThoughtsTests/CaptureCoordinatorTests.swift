import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct CaptureCoordinatorTests {
  static let own = "dev.example.thoughts"
  static let notes = AppSnapshot(pid: 41, bundleID: "com.apple.Notes", name: "Notes")
  static let editor = AppSnapshot(pid: 42, bundleID: "com.microsoft.VSCode", name: "Code")
  static let page = Source(app: "Notes", bundleID: "com.apple.Notes")

  @MainActor
  final class FakeReader: SelectionReading {
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
    image: (() -> ClipboardImage?)? = nil,
    offer: OfferID? = nil,
    accept: (() async throws -> Thought)? = nil
  ) throws -> Rig {
    let fixture = try ListFixture()
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
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
      currentOffer: offer.map { id in { id } }, acceptOffer: accept, clipboardImage: image)
    return Rig(
      fixture: fixture, board: board, reader: reader, writer: writer, coordinator: coordinator,
      plays: plays, defaults: defaults)
  }

  @Test func selectedTextIsSavedWithItsSourceAndPlaysTheSound() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
    rig.reader.probeResult = .text("quiet")
    _ = await rig.coordinator.capture()
    #expect(rig.plays.count == 0)
  }

  @Test func unavailableSelectionCopiesAndNotesBothChangeCounts() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
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
      defer { rig.board.releaseGlobally() }
      rig.reader.probeResult = probe
      #expect(await rig.coordinator.capture() == .nothingToSave)
      #expect(rig.reader.copies == 0)
      #expect(rig.plays.count == 0)
    }
  }

  @Test func anAppThatGivesNoEvidenceStillGetsTheCopyKey() async throws {
    let rig = try Self.rig()
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
    rig.reader.probeResult = .empty
    let outcome = await rig.coordinator.capture()
    #expect(outcome == .nothingToSave)
    #expect(rig.reader.copies == 0)
    #expect(rig.plays.count == 0)
    #expect(try rig.fixture.store.entries().isEmpty)
  }

  @Test func ownWindowBeingKeyNeverProbesOrCopiesFromTheAppBehindIt() async throws {
    let rig = try Self.rig(front: Self.notes, ownWindowIsKey: true)
    defer { rig.board.releaseGlobally() }
    rig.reader.probeResult = .text("text in the app behind")
    rig.reader.copyResult = .text("copied from the app behind")
    let outcome = await rig.coordinator.capture()
    #expect(outcome == .nothingToSave)
    #expect(rig.reader.probed.isEmpty)
    #expect(rig.reader.copies == 0)
  }

  @Test func recentClipboardImageIsSavedAndReportsItsChangeCount() async throws {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    let seen = ListFixture.now.addingTimeInterval(-30)
    let count = board.changeCount
    let fixture = try ListFixture()
    let reader = FakeReader()
    reader.probeResult = .empty
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let coordinator = CaptureCoordinator(
      frontmost: { Self.editor }, ownBundleID: Self.own, ownWindowIsKey: { false }, reader: reader,
      source: { Self.page },
      input: fixture.input, writer: PasteboardWriter(pasteboard: board),
      sound: SavedSound(preferences: Preferences(defaults: defaults), player: {}),
      pasteboard: board, now: { ListFixture.now },
      clipboardImage: { ClipboardImage(changeCount: count, seen: seen) })
    var saves: [ManualSave] = []
    fixture.input.onManualSave = { saves.append($0) }
    let outcome = await coordinator.capture()
    guard case .saved(let thought) = outcome, case .image = thought.content else {
      Issue.record("expected an image, got \(outcome)")
      return
    }
    #expect(saves.first?.pasteboardChangeCount == count)
  }

  static func imageRig(
    probe: SelectionProbe = .empty, front: AppSnapshot? = editor
  ) throws -> (
    fixture: ListFixture, board: NSPasteboard, reader: FakeReader, coordinator: CaptureCoordinator,
    count: Int
  ) {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    board.clearContents()
    board.setData(try ListFixture.png(), forType: .png)
    let count = board.changeCount
    let fixture = try ListFixture()
    let reader = FakeReader()
    reader.probeResult = probe
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let coordinator = CaptureCoordinator(
      frontmost: { front }, ownBundleID: own, ownWindowIsKey: { false }, reader: reader,
      source: { page }, input: fixture.input, writer: PasteboardWriter(pasteboard: board),
      sound: SavedSound(preferences: Preferences(defaults: defaults), player: {}),
      pasteboard: board, now: { ListFixture.now },
      clipboardImage: {
        ClipboardImage(
          changeCount: board.changeCount, seen: ListFixture.now.addingTimeInterval(-30))
      })
    return (fixture, board, reader, coordinator, count)
  }

  @Test func shiftShiftTwiceOnOneImageCopySavesItOnce() async throws {
    let rig = try Self.imageRig()
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
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
    defer { rig.board.releaseGlobally() }
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
    defer { rig.board.releaseGlobally() }
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

  @Test func aNonImageFileOnTheClipboardIsNotSavedAsItsIcon() throws {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
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
      front: Self.editor, image: { ClipboardImage(changeCount: -1, seen: ListFixture.now) })
    defer { rig.board.releaseGlobally() }
    rig.reader.probeResult = .empty
    #expect(await rig.coordinator.capture() == .nothingToSave)
  }

  @Test func offerIsAcceptedBeforeAnySelectionIsRead() async throws {
    let fixture = try ListFixture()
    let thought = try fixture.addText("From the offer", daysAgo: 0)
    let rig = try Self.rig(offer: OfferID(), accept: { thought })
    defer { rig.board.releaseGlobally() }
    let outcome = await rig.coordinator.capture()
    #expect(outcome == .acceptedOffer(thought))
    #expect(rig.reader.probed.isEmpty)
    #expect(rig.plays.count == 0)
  }

  @Test func failedOfferShowsItsMessage() async throws {
    let rig = try Self.rig(
      offer: OfferID(), accept: { throw ThoughtsError.clipboardChanged })
    defer { rig.board.releaseGlobally() }
    #expect(
      await rig.coordinator.capture()
        == .failed(ListModel.message(for: ThoughtsError.clipboardChanged)))
  }
}

@MainActor
struct GesturePreferencesTests {
  @Test func gestureStartsOnShiftAndSoundOnThenBothPersist() throws {
    let suite = "thoughts.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
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
    #expect(GestureMonitor.event(type: .leftMouseDown, flags: [], at: 1) == nil)
  }
}

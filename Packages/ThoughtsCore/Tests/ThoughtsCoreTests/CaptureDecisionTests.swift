import Foundation
import Testing

@testable import ThoughtsCore

struct CaptureDecisionTests {
  static let now = Date(timeIntervalSince1970: 1_795_000_000)

  static func context(
    offer: OfferID? = nil,
    selection: SelectionProbe,
    fallbackAllowed: Bool = true,
    imageAge: TimeInterval? = nil,
    imageCount: Int = 7,
    copy: ClipboardCopy.Kind = .image,
    copyApp: AppSnapshot? = nil,
    copyOwn: Bool = false,
    changeCount: Int = 7,
    equivalentCounts: [Int] = [],
    content: ClipboardContent? = nil,
    saved: SavedLedger = SavedLedger(),
    source: Source = Self.page
  ) -> CaptureContext {
    CaptureContext(
      offer: offer,
      selection: selection,
      fallbackAllowed: fallbackAllowed,
      clipboard: imageAge.map {
        ClipboardCopy(
          changeCount: imageCount, seen: now.addingTimeInterval(-$0), kind: copy, app: copyApp,
          own: copyOwn)
      },
      clipboardContent: content,
      changeCount: changeCount,
      equivalentCounts: equivalentCounts,
      saved: saved,
      source: source,
      now: now)
  }

  static let page = Source(app: "Notes", bundleID: "com.apple.Notes", window: "Groceries")
  static let other = Source(app: "Safari", bundleID: "com.apple.Safari")
  static let terminal = AppSnapshot(pid: 9, bundleID: "dev.example.terminal", name: "Terminal")
  static let terminalSource = Source(app: "Terminal", bundleID: "dev.example.terminal")
  static let file = URL(fileURLWithPath: "/tmp/thoughts/a.md")

  static func ledger(_ entries: SavedEntry...) -> SavedLedger {
    SavedLedger(entries: entries)
  }

  @Test func offerWinsOverSelection() {
    let offer = OfferID()
    let action = CaptureDecision.decide(Self.context(offer: offer, selection: .text("hello")))
    #expect(action == .acceptOffer(offer))
  }

  @Test func selectedTextIsSaved() {
    #expect(CaptureDecision.decide(Self.context(selection: .text("hello"))) == .saveText("hello"))
  }

  @Test func whitespaceSelectionCountsAsEmpty() {
    let withFallback = CaptureDecision.decide(Self.context(selection: .text(" \n\t ")))
    #expect(withFallback == .copyFallback)
    let without = CaptureDecision.decide(
      Self.context(selection: .text(" \n"), fallbackAllowed: false, imageAge: 5))
    #expect(without == .saveClipboardImage)
  }

  @Test func anEmptyAnswerFromASelectableElementNeverAsksForCopy() {
    #expect(CaptureDecision.decide(Self.context(selection: .empty)) == .nothingToSave)
    #expect(
      CaptureDecision.decide(Self.context(selection: .empty, imageAge: 5)) == .saveClipboardImage)
  }

  @Test func aDisabledCopyItemNeverAsksForCopy() {
    #expect(CaptureDecision.decide(Self.context(selection: .copyDisabled)) == .nothingToSave)
    #expect(
      CaptureDecision.decide(Self.context(selection: .copyDisabled, imageAge: 5))
        == .saveClipboardImage)
  }

  @Test func emptyAnswerInAnAppThatCopiesWithoutASelectionSkipsCopy() {
    let action = CaptureDecision.decide(Self.context(selection: .empty, fallbackAllowed: false))
    #expect(action == .nothingToSave)
  }

  @Test func unavailableSelectionAsksForCopy() {
    #expect(CaptureDecision.decide(Self.context(selection: .unavailable)) == .copyFallback)
  }

  @Test func disallowedFallbackSkipsCopy() {
    let action = CaptureDecision.decide(
      Self.context(selection: .unavailable, fallbackAllowed: false, imageAge: 10))
    #expect(action == .saveClipboardImage)
  }

  @Test func passwordFieldSavesNothing() {
    let action = CaptureDecision.decide(Self.context(selection: .secureField, imageAge: 10))
    #expect(action == .nothingToSave)
  }

  @Test func copiedNothingFallsToRecentImage() {
    let action = CaptureDecision.decide(Self.context(selection: .copiedNothing, imageAge: 30))
    #expect(action == .saveClipboardImage)
    #expect(CaptureDecision.decide(Self.context(selection: .copiedNothing)) == .nothingToSave)
  }

  @Test func imageOlderThanTwoMinutesIsIgnored() {
    let action = CaptureDecision.decide(Self.context(selection: .copiedNothing, imageAge: 121))
    #expect(action == .nothingToSave)
    let edge = CaptureDecision.decide(Self.context(selection: .copiedNothing, imageAge: 120))
    #expect(edge == .saveClipboardImage)
  }

  @Test func changedClipboardIsIgnored() {
    let action = CaptureDecision.decide(
      Self.context(selection: .copiedNothing, imageAge: 10, imageCount: 7, changeCount: 8))
    #expect(action == .nothingToSave)
  }

  @Test func theSameTextFromTheSameSourceAsTheNewestThoughtIsAlreadySaved() {
    let saved = Self.ledger(SavedEntry(file: Self.file, text: "milk", source: Self.page))
    let again = CaptureDecision.decide(
      Self.context(selection: .text(" milk\n"), saved: saved))
    #expect(again == .alreadySaved(Self.file))
  }

  @Test func differentTextOrASourceThatDiffersSavesAgain() {
    let saved = Self.ledger(SavedEntry(file: Self.file, text: "milk", source: Self.page))
    let different = CaptureDecision.decide(Self.context(selection: .text("eggs"), saved: saved))
    #expect(different == .saveText("eggs"))
    let elsewhere = CaptureDecision.decide(
      Self.context(selection: .text("milk"), saved: saved, source: Self.other))
    #expect(elsewhere == .saveText("milk"))
  }

  @Test func textRepeatsOnlyAgainstTheNewestThought() {
    let saved = Self.ledger(
      SavedEntry(file: Self.file, text: "milk", source: Self.page),
      SavedEntry(file: URL(fileURLWithPath: "/tmp/thoughts/b.md"), text: "eggs", source: Self.page))
    #expect(
      CaptureDecision.decide(Self.context(selection: .text("milk"), saved: saved))
        == .saveText("milk"))
    #expect(
      CaptureDecision.decide(Self.context(selection: .text("eggs"), saved: saved))
        == .alreadySaved(URL(fileURLWithPath: "/tmp/thoughts/b.md")))
  }

  @Test func textSavesAgainOnceTheNewestThoughtIsDeleted() {
    let saved = Self.ledger(SavedEntry(file: Self.file, text: "milk", source: Self.page))
    let afterDelete = saved.pruned { _ in false }
    #expect(
      CaptureDecision.decide(Self.context(selection: .text("milk"), saved: afterDelete))
        == .saveText("milk"))
    #expect(
      CaptureDecision.decide(
        Self.context(selection: .text("milk"), saved: saved.pruned { _ in true }))
        == .alreadySaved(Self.file))
  }

  @Test func aClipboardImageThatWasSavedIsSavedOnlyOnce() {
    let saved = Self.ledger(SavedEntry(file: Self.file, clipboardCounts: [7]))
    let again = CaptureDecision.decide(
      Self.context(selection: .copiedNothing, imageAge: 10, saved: saved))
    #expect(again == .alreadySaved(Self.file))
  }

  @Test func theMatchNamesTheNewestThoughtHoldingTheImage() {
    let newer = URL(fileURLWithPath: "/tmp/thoughts/b.md")
    let saved = Self.ledger(
      SavedEntry(file: Self.file, clipboardCounts: [7]),
      SavedEntry(file: newer, clipboardCounts: [7]))
    let again = CaptureDecision.decide(
      Self.context(selection: .copiedNothing, imageAge: 10, saved: saved))
    #expect(again == .alreadySaved(newer))
  }

  @Test func aNewCopyOfTheSameImageSavesAgain() {
    let saved = Self.ledger(SavedEntry(file: Self.file, clipboardCounts: [7]))
    let fresh = CaptureDecision.decide(
      Self.context(
        selection: .copiedNothing, imageAge: 10, imageCount: 9, changeCount: 9, saved: saved))
    #expect(fresh == .saveClipboardImage)
  }

  @Test func anImageKeptThroughTheOfferCountsAsSaved() {
    let kept = Self.ledger(SavedEntry(file: Self.file, clipboardCounts: [7]))
    #expect(
      CaptureDecision.decide(
        Self.context(selection: .unavailable, fallbackAllowed: false, imageAge: 40, saved: kept))
        == .alreadySaved(Self.file))
  }

  @Test func theCountBeforeACopyRoundTripStillNamesTheSavedImage() {
    let saved = Self.ledger(SavedEntry(file: Self.file, clipboardCounts: [7]))
    let afterRoundTrip = CaptureDecision.decide(
      Self.context(
        selection: .copiedNothing, imageAge: 10, imageCount: 9, changeCount: 9,
        equivalentCounts: [7], saved: saved))
    #expect(afterRoundTrip == .alreadySaved(Self.file))
  }

  @Test func anImageSavesAgainOnceItsThoughtIsDeleted() {
    let saved = Self.ledger(SavedEntry(file: Self.file, clipboardCounts: [7]))
    let afterDelete = saved.pruned { _ in false }
    #expect(
      CaptureDecision.decide(
        Self.context(selection: .copiedNothing, imageAge: 10, saved: afterDelete))
        == .saveClipboardImage)
  }

  @Test func aTextCopyAsksForTheClipboardBeforeItSaves() {
    let asked = CaptureDecision.decide(
      Self.context(selection: .empty, imageAge: 60, copy: .text, copyApp: Self.terminal))
    #expect(asked == .readClipboard)
    let unknown = CaptureDecision.decide(
      Self.context(selection: .copiedNothing, imageAge: 60, copy: .unknown))
    #expect(unknown == .readClipboard)
  }

  @Test func textCopiedOneMinuteAgoSavesAndTextCopiedThreeMinutesAgoDoesNot() {
    let recent = CaptureDecision.decide(
      Self.context(
        selection: .empty, imageAge: 60, copy: .text, copyApp: Self.terminal,
        content: .text("from the terminal")))
    #expect(recent == .saveCopiedText("from the terminal", Self.terminalSource))
    let old = CaptureDecision.decide(
      Self.context(
        selection: .empty, imageAge: 180, copy: .text, copyApp: Self.terminal,
        content: .text("from the terminal")))
    #expect(old == .nothingToSave)
    let edge = CaptureDecision.decide(
      Self.context(selection: .empty, imageAge: 120, copy: .text, copyApp: Self.terminal))
    #expect(edge == .readClipboard)
    #expect(
      CaptureDecision.decide(Self.context(selection: .empty, imageAge: 121, copy: .text))
        == .nothingToSave)
  }

  @Test func aCopyThatChangedSinceItWasNotedIsIgnored() {
    let action = CaptureDecision.decide(
      Self.context(
        selection: .empty, imageAge: 10, imageCount: 7, copy: .text, changeCount: 8,
        content: .text("old")))
    #expect(action == .nothingToSave)
  }

  @Test func theCopiedTextRecordsTheAppThatCopiedItAndTheWindowOnlyWhileItIsFrontmost() {
    let frontmost = Source(
      app: "Terminal", bundleID: "dev.example.terminal", window: "~/code", title: "~/code")
    let still = CaptureDecision.decide(
      Self.context(
        selection: .empty, imageAge: 20, copy: .text, copyApp: Self.terminal, content: .text("ls"),
        source: frontmost))
    #expect(still == .saveCopiedText("ls", frontmost))
    let moved = CaptureDecision.decide(
      Self.context(
        selection: .empty, imageAge: 20, copy: .text, copyApp: Self.terminal, content: .text("ls"),
        source: Self.page))
    #expect(moved == .saveCopiedText("ls", Self.terminalSource))
    let unknown = CaptureDecision.decide(
      Self.context(
        selection: .empty, imageAge: 20, copy: .text, content: .text("ls"), source: Self.page))
    #expect(unknown == .saveCopiedText("ls", Source()))
  }

  @Test func aSavedTextCopyIsSavedOnlyOnce() {
    let saved = Self.ledger(
      SavedEntry(file: Self.file, clipboardCounts: [7], text: "ls", source: Self.terminalSource))
    let again = CaptureDecision.decide(
      Self.context(
        selection: .empty, imageAge: 20, copy: .text, copyApp: Self.terminal, saved: saved))
    #expect(again == .alreadySaved(Self.file))
  }

  @Test func aNewCopyOfTheSameTextFromTheSameAppIsAlreadySaved() {
    let saved = Self.ledger(
      SavedEntry(file: Self.file, clipboardCounts: [7], text: "ls", source: Self.terminalSource))
    let fresh = CaptureDecision.decide(
      Self.context(
        selection: .empty, imageAge: 20, imageCount: 9, copy: .text, copyApp: Self.terminal,
        changeCount: 9, content: .text(" ls\n"), saved: saved))
    #expect(fresh == .alreadySaved(Self.file))
    let elsewhere = CaptureDecision.decide(
      Self.context(
        selection: .empty, imageAge: 20, imageCount: 9,
        copy: .text, copyApp: AppSnapshot(pid: 5, bundleID: "com.apple.Safari", name: "Safari"),
        changeCount: 9, content: .text("ls"), saved: saved))
    #expect(elsewhere == .saveCopiedText("ls", Self.other))
  }

  @Test func aTextCopySavesAgainOnceItsThoughtIsDeleted() {
    let saved = Self.ledger(
      SavedEntry(file: Self.file, clipboardCounts: [7], text: "ls", source: Self.terminalSource))
    let action = CaptureDecision.decide(
      Self.context(
        selection: .empty, imageAge: 20, copy: .text, copyApp: Self.terminal, content: .text("ls"),
        saved: saved.pruned { _ in false }))
    #expect(action == .saveCopiedText("ls", Self.terminalSource))
  }

  @Test func aSelectionBeatsACopy() {
    let action = CaptureDecision.decide(
      Self.context(
        selection: .text("selected"), imageAge: 20, copy: .text, copyApp: Self.terminal,
        content: .text("copied")))
    #expect(action == .saveText("selected"))
  }

  @Test func anImageCopyBeatsTextInTheSameCopy() {
    let action = CaptureDecision.decide(
      Self.context(selection: .empty, imageAge: 20, copy: .image, copyApp: Self.terminal))
    #expect(action == .saveClipboardImage)
    let read = CaptureDecision.decide(
      Self.context(selection: .empty, imageAge: 20, copy: .unknown, content: .image))
    #expect(read == .saveClipboardImage)
  }

  @Test func blankOrMissingClipboardTextSavesNothing() {
    for content in [ClipboardContent.nothing, .text("  \n")] {
      let action = CaptureDecision.decide(
        Self.context(selection: .empty, imageAge: 20, copy: .unknown, content: content))
      #expect(action == .nothingToSave)
    }
  }

  @Test func thoughtsOwnTextCopiesNeverCountButItsImageCopiesStillDo() {
    #expect(
      CaptureDecision.decide(
        Self.context(selection: .empty, imageAge: 20, copy: .text, copyOwn: true))
        == .nothingToSave)
    #expect(
      CaptureDecision.decide(
        Self.context(
          selection: .empty, imageAge: 20, copy: .unknown, copyOwn: true, content: .text("mine")))
        == .nothingToSave)
    #expect(
      CaptureDecision.decide(
        Self.context(selection: .empty, imageAge: 20, copy: .image, copyOwn: true))
        == .saveClipboardImage)
  }

  @Test func theCountBeforeACopyRoundTripStillNamesTheSavedText() {
    let saved = Self.ledger(
      SavedEntry(file: Self.file, clipboardCounts: [7], text: "ls", source: Self.terminalSource))
    let after = CaptureDecision.decide(
      Self.context(
        selection: .copiedNothing, imageAge: 10, imageCount: 9, copy: .text, copyApp: Self.terminal,
        changeCount: 9, equivalentCounts: [7], saved: saved))
    #expect(after == .alreadySaved(Self.file))
  }

  @Test func copiesMarkedConcealedTransientOrAutoGeneratedAreExcluded() {
    for type in [
      "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
      "org.nspasteboard.AutoGeneratedType",
    ] {
      #expect(ClipboardTypes.isExcluded(["public.utf8-plain-text", type]))
    }
    #expect(!ClipboardTypes.isExcluded(["public.utf8-plain-text", "public.png"]))
    #expect(!ClipboardTypes.isExcluded([]))
    #expect(ClipboardTypes.isConcealed(["org.nspasteboard.ConcealedType"]))
    #expect(!ClipboardTypes.isConcealed(["org.nspasteboard.TransientType"]))
  }

  @Test func aRefusedClipboardReadIsNeverNothingToSave() {
    for kind in [ClipboardCopy.Kind.text, .image, .unknown] {
      let action = CaptureDecision.decide(
        Self.context(selection: .empty, imageAge: 20, copy: kind, content: .refused))
      #expect(action == .clipboardRefused)
    }
    let own = CaptureDecision.decide(
      Self.context(selection: .empty, imageAge: 20, copy: .text, copyOwn: true, content: .refused))
    #expect(own == .nothingToSave)
    let stale = CaptureDecision.decide(
      Self.context(selection: .empty, imageAge: 200, copy: .unknown, content: .refused))
    #expect(stale == .nothingToSave)
  }

  @Test func aMovedCopyKeepsItsKindAppAndAge() {
    let copy = ClipboardCopy(
      changeCount: 7, seen: Self.now, kind: .text, app: Self.terminal, own: true)
    #expect(
      copy.moved(to: 9)
        == ClipboardCopy(changeCount: 9, seen: Self.now, kind: .text, app: Self.terminal, own: true)
    )
  }

  @Test func theLedgerKeepsOnlyTheLatestSixtyFour() {
    var ledger = SavedLedger()
    for index in 0..<(SavedLedger.remembered + 5) {
      ledger.record(
        SavedEntry(file: URL(fileURLWithPath: "/tmp/\(index).md"), clipboardCounts: [index]))
    }
    #expect(ledger.entries.count == SavedLedger.remembered)
    #expect(ledger.newestHolding(counts: [0]) == nil)
    #expect(ledger.newestHolding(counts: [SavedLedger.remembered + 4]) != nil)
  }

  @Test func appsThatCopyALineOrCellWithNothingSelectedSkipTheCopy() {
    let own = "dev.example.thoughts"
    for bundleID in [
      "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.sublimetext.4",
      "com.jetbrains.intellij", "com.jetbrains.pycharm.ce", "com.microsoft.Excel",
      "com.apple.Numbers", own,
    ] {
      #expect(!CopyFallbackPolicy.allowed(bundleID: bundleID, ownBundleID: own))
    }
    for bundleID in ["com.apple.Safari", "com.tinyspeck.slackmacgap", "com.apple.TextEdit"] {
      #expect(CopyFallbackPolicy.allowed(bundleID: bundleID, ownBundleID: own))
    }
    #expect(CopyFallbackPolicy.allowed(bundleID: nil, ownBundleID: own))
  }
}

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
    changeCount: Int = 7
  ) -> CaptureContext {
    CaptureContext(
      offer: offer,
      selection: selection,
      fallbackAllowed: fallbackAllowed,
      clipboardImage: imageAge.map {
        ClipboardImage(changeCount: imageCount, seen: now.addingTimeInterval(-$0))
      },
      changeCount: changeCount,
      now: now)
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

  @Test func emptyAnswerAsksForCopy() {
    #expect(CaptureDecision.decide(Self.context(selection: .empty)) == .copyFallback)
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

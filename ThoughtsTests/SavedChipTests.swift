import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct SavedChipTests {
  static let page = Source(app: "Safari", bundleID: "com.apple.Safari")
  static let file = Source(app: "Finder", file: "/Users/someone/Desktop/cat photo.png")

  static func saved(_ thought: Thought) async -> HintChipView {
    HintChipView(kind: .saved(await SavedPreview.load(thought)))
  }

  static func already(_ thought: Thought) async -> HintChipView {
    HintChipView(kind: .alreadySaved(await SavedPreview.load(thought)))
  }

  @Test func savedTextShowsItsTrimmedStartAndNoThumbnail() async throws {
    let fixture = try ListFixture()
    let thought = try fixture.addText("  It fills up after 10\n\n so get on early  ", daysAgo: 0)
    let chip = await Self.saved(thought)
    #expect(chip.line == "It fills up after 10 so get on early")
    #expect(chip.thumbnail == nil)
    #expect(chip.spokenText == "Saved, It fills up after 10 so get on early")
  }

  @Test func aLongTextIsCutToTheLimitForTheChipToEllipsize() async throws {
    let fixture = try ListFixture()
    let long = String(repeating: "word ", count: 200)
    let thought = try fixture.addText(long, daysAgo: 0)
    let line = try #require(await Self.saved(thought).line)
    #expect(line.count == SavedPreview.characterLimit)
    #expect(long.hasPrefix(line))
  }

  @Test func anImageFromAFileShowsTheThumbnailAndTheFileName() async throws {
    let fixture = try ListFixture()
    let thought = try fixture.addScreenshot(note: "", daysAgo: 0, source: Self.file)
    let chip = await Self.saved(thought)
    #expect(chip.line == "cat photo.png")
    let thumbnail = try #require(chip.thumbnail)
    #expect(thumbnail.size.width <= 40 && thumbnail.size.height <= 40)
    #expect(chip.spokenText == "Saved, cat photo.png")
  }

  @Test func anImageWithoutAFileNamesTheSourceApp() async throws {
    let fixture = try ListFixture()
    let thought = try fixture.addScreenshot(note: "  ", daysAgo: 0, source: Self.page)
    let chip = await Self.saved(thought)
    #expect(chip.line == "Safari")
    #expect(chip.thumbnail != nil)
  }

  @Test func anImageWithANoteShowsTheFirstLineOfTheNote() async throws {
    let fixture = try ListFixture()
    let thought = try fixture.addScreenshot(
      note: "\n  Fix this padding \nthen ship", daysAgo: 0, source: Self.file)
    let chip = await Self.saved(thought)
    #expect(chip.line == "Fix this padding")
    #expect(chip.thumbnail != nil)
  }

  @Test func anImageWithNoNoteFileOrAppShowsOnlyTheTitleAndTheThumbnail() async throws {
    let fixture = try ListFixture()
    let thought = try fixture.addScreenshot(note: "", daysAgo: 0)
    let chip = await Self.saved(thought)
    #expect(chip.line == nil)
    #expect(chip.thumbnail != nil)
    #expect(chip.spokenText == "Saved")
  }

  @Test func alreadySavedShowsTheThoughtThatHoldsTheCopy() async throws {
    let fixture = try ListFixture()
    let text = try fixture.addText("buy oat milk", daysAgo: 0)
    let textChip = await Self.already(text)
    #expect(textChip.line == "buy oat milk")
    #expect(textChip.thumbnail == nil)
    #expect(textChip.spokenText == "Already saved, buy oat milk")
    let image = try fixture.addScreenshot(note: "", daysAgo: 0, source: Self.file)
    let imageChip = await Self.already(image)
    #expect(imageChip.line == "cat photo.png")
    #expect(imageChip.thumbnail != nil)
  }

  @Test func alreadySavedWithoutAReadableThoughtKeepsItsOldLine() {
    let chip = HintChipView(kind: .alreadySaved(.withoutThought))
    #expect(chip.line == "It is already in your thoughts")
    #expect(chip.thumbnail == nil)
  }

  @Test func theChipsWithNothingToShowCarryWordsOnly() {
    let nothing = HintChipView(kind: .nothingToSave)
    #expect(nothing.thumbnail == nil)
    #expect(nothing.spokenText == "Nothing to save, Select or copy something first")
    let failed = HintChipView(kind: .failed("The thoughts folder isn't available."))
    #expect(failed.thumbnail == nil)
    #expect(failed.spokenText == "Couldn't save, The thoughts folder isn't available.")
  }

  @Test func everyChipKeepsTheSameSizeWithOrWithoutAThumbnail() throws {
    let image = try OfferChipTests.thumbnail()
    let chips: [HintChipView.Kind] = [
      .saved(SavedPreview(line: "words", thumbnail: nil)),
      .saved(SavedPreview(line: String(repeating: "long ", count: 80), thumbnail: image)),
      .saved(SavedPreview(line: nil, thumbnail: image)),
      .alreadySaved(SavedPreview(line: "words", thumbnail: image)),
      .nothingToSave,
      .failed(String(repeating: "long ", count: 80)),
    ]
    for kind in chips {
      let size = NSHostingView(rootView: HintChipView(kind: kind)).fittingSize
      #expect(size == CGSize(width: 300, height: 60))
    }
  }

  @Test func everyHintChipStaysForTheSameLifetime() {
    let preview = SavedPreview(line: "words", thumbnail: nil)
    let kinds: [HintChipView.Kind] = [
      .saved(preview), .alreadySaved(preview), .nothingToSave, .failed("no"),
    ]
    #expect(Set(kinds.map(\.lifetime)) == [2.4])
  }
}

import Foundation
import Testing

@testable import ThoughtsCore

struct OfferQueueTests {
  static let start = Date(timeIntervalSince1970: 1_795_000_000)
  static let shot = URL(fileURLWithPath: "/tmp/screens/shot.png")
  static let other = URL(fileURLWithPath: "/tmp/screens/other.png")

  static func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

  @Test func clipboardImageMakesOffer() {
    var queue = OfferQueue()
    let source = Source(app: "Preview")
    let update = queue.add(.clipboard(changeCount: 4, file: nil, at: Self.at(0)), source: source)
    guard case .show(let offer) = update else {
      Issue.record("expected show, got \(update)")
      return
    }
    #expect(offer.changeCount == 4)
    #expect(offer.file == nil)
    #expect(offer.source == source)
    #expect(queue.current == offer)
  }

  @Test func fileAfterClipboardMergesAndKeepsFile() {
    var queue = OfferQueue()
    guard
      case .show(let first) = queue.add(
        .clipboard(changeCount: 4, file: nil, at: Self.at(0)), source: Source(app: "Preview"))
    else {
      Issue.record("expected show")
      return
    }
    let update = queue.add(.file(Self.shot, at: Self.at(1.2)), source: Source(app: "Other"))
    guard case .update(let merged) = update else {
      Issue.record("expected update, got \(update)")
      return
    }
    #expect(merged.id == first.id)
    #expect(merged.file == Self.shot)
    #expect(merged.changeCount == 4)
    #expect(merged.source == Source(app: "Preview"))
    #expect(queue.current == merged)
  }

  @Test func clipboardAfterFileMerges() {
    var queue = OfferQueue()
    guard case .show(let first) = queue.add(.file(Self.shot, at: Self.at(0)), source: nil) else {
      Issue.record("expected show")
      return
    }
    let update = queue.add(
      .clipboard(changeCount: 9, file: nil, at: Self.at(0.8)), source: Source(app: "Preview"))
    guard case .update(let merged) = update else {
      Issue.record("expected update, got \(update)")
      return
    }
    #expect(merged.id == first.id)
    #expect(merged.file == Self.shot)
    #expect(merged.changeCount == 9)
    #expect(merged.source == Source(app: "Preview"))
  }

  @Test func ownChangeCountIsIgnored() {
    var queue = OfferQueue()
    queue.noteOwn(changeCount: 5)
    let update = queue.add(.clipboard(changeCount: 5, file: nil, at: Self.at(0)), source: nil)
    #expect(update == .ignore)
    #expect(queue.current == nil)
  }

  @Test func ownChangeDropsTheOfferHoldingIt() {
    var queue = OfferQueue()
    _ = queue.add(.clipboard(changeCount: 5, file: nil, at: Self.at(0)), source: nil)
    queue.noteOwn(changeCount: 5)
    #expect(queue.current == nil)
  }

  @Test func savedByHandIsNeverOffered() {
    var queue = OfferQueue()
    queue.noteSaved(changeCount: 7, file: nil, at: Self.at(0))
    let clipboard = queue.add(.clipboard(changeCount: 7, file: nil, at: Self.at(0.5)), source: nil)
    #expect(clipboard == .ignore)
    #expect(queue.add(.file(Self.shot, at: Self.at(2)), source: nil) == .ignore)
    #expect(queue.current == nil)
  }

  @Test func savedFileIsNeverOffered() {
    var queue = OfferQueue()
    queue.noteSaved(changeCount: nil, file: Self.shot, at: Self.at(0))
    #expect(queue.add(.file(Self.shot, at: Self.at(30)), source: nil) == .ignore)
    guard case .show = queue.add(.file(Self.other, at: Self.at(30)), source: nil) else {
      Issue.record("an unsaved file should still be offered")
      return
    }
  }

  @Test func savingTheOfferedImageDropsTheOffer() {
    var queue = OfferQueue()
    _ = queue.add(.clipboard(changeCount: 3, file: nil, at: Self.at(0)), source: nil)
    queue.noteSaved(changeCount: 3, file: nil, at: Self.at(1))
    #expect(queue.current == nil)
  }

  @Test func laterSignalReplacesOffer() {
    var queue = OfferQueue()
    guard
      case .show(let first) = queue.add(
        .clipboard(changeCount: 1, file: nil, at: Self.at(0)), source: nil)
    else {
      Issue.record("expected show")
      return
    }
    let update = queue.add(.clipboard(changeCount: 2, file: nil, at: Self.at(4)), source: nil)
    guard case .show(let second) = update else {
      Issue.record("expected show, got \(update)")
      return
    }
    #expect(second.id != first.id)
    #expect(queue.current?.changeCount == 2)
  }

  @Test func offerExpiresAfterSixSeconds() {
    var queue = OfferQueue()
    _ = queue.add(.clipboard(changeCount: 1, file: nil, at: Self.at(0)), source: nil)
    let early = queue.expire(now: Self.at(5.9))
    #expect(!early)
    #expect(queue.current != nil)
    let due = queue.expire(now: Self.at(6))
    #expect(due)
    #expect(queue.current == nil)
    let again = queue.expire(now: Self.at(7))
    #expect(!again)
  }

  @Test func mergingExtendsTheLifetime() {
    var queue = OfferQueue()
    _ = queue.add(.clipboard(changeCount: 1, file: nil, at: Self.at(0)), source: nil)
    _ = queue.add(.file(Self.shot, at: Self.at(2)), source: nil)
    let early = queue.expire(now: Self.at(7))
    #expect(!early)
    let due = queue.expire(now: Self.at(8))
    #expect(due)
  }

  @Test func takeClearsCurrent() {
    var queue = OfferQueue()
    _ = queue.add(.file(Self.shot, at: Self.at(0)), source: nil)
    let taken = queue.take()
    #expect(taken?.file == Self.shot)
    #expect(queue.current == nil)
    #expect(queue.take() == nil)
  }
}

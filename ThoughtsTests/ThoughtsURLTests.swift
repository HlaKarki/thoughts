import Foundation
import Testing

@testable import Thoughts

struct ThoughtsURLTests {
  private func parse(_ string: String) -> ThoughtsURL? {
    URL(string: string).flatMap(ThoughtsURL.init)
  }

  @Test func parsesAddText() {
    #expect(parse("thoughts://add?text=Buy%20milk") == .add(text: "Buy milk"))
    #expect(parse("thoughts-dev://add?text=Buy%20milk") == .add(text: "Buy milk"))
  }

  @Test func parsesAddImageWithNote() {
    #expect(
      parse("thoughts://add?image=/tmp/Shot%201.png&note=Toast%20overlaps%20the%20header")
        == .addImage(path: "/tmp/Shot 1.png", note: "Toast overlaps the header"))
    #expect(
      parse("thoughts://add?image=/tmp/Shot.png") == .addImage(path: "/tmp/Shot.png", note: ""))
  }

  @Test func rejectsUnknownHost() {
    #expect(parse("thoughts://delete") == nil)
    #expect(parse("thoughts://delete?text=Buy%20milk") == nil)
    #expect(parse("thoughts://show") == .show)
    #expect(parse("thoughts://import") == .importInbox)
  }

  @Test func rejectsEmptyText() {
    #expect(parse("thoughts://add") == nil)
    #expect(parse("thoughts://add?text=") == nil)
    #expect(parse("thoughts://add?text=%20%0A%20") == nil)
  }
}

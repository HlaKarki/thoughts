import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized, .throwaway)
struct PanelPromptTests {
  typealias Rig = LiveEdgeTests.Rig
  typealias Apps = FrontReturnTests.Apps

  @MainActor
  final class Log {
    var events: [String] = []
  }

  static func rig(keepOpen: Bool = false) throws -> (rig: Rig, apps: Apps) {
    let rig = try Rig(edge: .right)
    rig.preferences.keepOpen = keepOpen
    let apps = Apps()
    apps.front = Apps.finder
    let returns = apps.returns
    let controller = rig.controller
    rig.fixture.input.hooks = FrontReturn.Hooks(read: { controller.holdThroughPrompt(returns) })
    return (rig, apps)
  }

  static func loseKey(_ rig: Rig) {
    rig.key.window = nil
    NotificationCenter.default.post(
      name: NSWindow.didResignKeyNotification, object: rig.controller.panel)
  }

  struct Composer {
    let panel: NSPanel
    let editor: NSTextView
  }

  static func compose(_ rig: Rig) async throws -> Composer {
    let panel = rig.controller.panel
    let content = try #require(panel.contentView)
    content.layoutSubtreeIfNeeded()
    let field = try #require(PasteFieldTests.inputFields(in: content).first)
    #expect(panel.makeFirstResponder(field))
    rig.fixture.input.text = "Orange"
    await InputFocusTests.settle()
    let editor = try #require(field.currentEditor() as? NSTextView)
    editor.setSelectedRange(NSRange(location: 3, length: 0))
    return Composer(panel: panel, editor: editor)
  }

  static func pasteFile(_ rig: Rig, in folder: TempFolder) throws {
    let file = try FileReadThreadTests.file(named: "Orange block.png", in: folder)
    let board = Throwaway.pasteboard()
    try InputModelTests.fill(board, file: file, text: "Orange block.png", image: false)
    #expect(rig.fixture.input.takeImage(from: board))
  }

  static func expectKept(_ rig: Rig, _ composer: Composer) {
    if case .image(.file(let attached), _) = rig.fixture.input.attachment {
      #expect(attached.lastPathComponent == "Orange block.png")
    } else {
      Issue.record("expected the pasted image file")
    }
    #expect(rig.fixture.input.text == "Orange")
    #expect(composer.panel.firstResponder === composer.editor)
    #expect(composer.editor.selectedRange() == NSRange(location: 3, length: 0))
  }

  static func finish(_ rig: Rig, _ composer: Composer) {
    _ = composer.panel.makeFirstResponder(nil)
    rig.controller.hide()
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func aPasteThatWaitsOnAFolderPromptKeepsThePanelWithItsCaretAndMakesItKeyAgain()
    async throws
  {
    let (rig, apps) = try Self.rig()
    apps.activate(Apps.folderPrompt)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: true)
    let made = rig.key.made
    let composer = try await Self.compose(rig)
    let folder = TempFolder()
    try Self.pasteFile(rig, in: folder)
    await rig.fixture.input.pasteRead?.value
    Self.loseKey(rig)
    #expect(rig.controller.isShown)
    apps.answerFolderPrompt()
    await InputFocusTests.settle()
    #expect(rig.controller.isShown)
    #expect(rig.controller.isKey)
    #expect(rig.key.made == made + 1)
    Self.expectKept(rig, composer)
    Self.finish(rig, composer)
  }

  @Test func aPasteWaitingOnAPromptAlreadyUpComesBackWhenFinderActivatesBeforeThePromptLeaves()
    async throws
  {
    let (rig, apps) = try Self.rig()
    apps.activate(Apps.folderPrompt)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: true)
    let made = rig.key.made
    let composer = try await Self.compose(rig)
    let folder = TempFolder()
    try Self.pasteFile(rig, in: folder)
    await rig.fixture.input.pasteRead?.value
    Self.loseKey(rig)
    apps.activate(Apps.finder)
    #expect(rig.controller.isShown)
    #expect(!rig.controller.isKey)
    apps.close(Apps.folderPrompt)
    await apps.runChecks(after: 1)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { rig.controller.isKey })
    #expect(rig.controller.isShown)
    #expect(rig.key.made == made + 1)
    Self.expectKept(rig, composer)
    Self.finish(rig, composer)
  }

  @Test func aPastePromptAnsweredAfterTheReadLandsMakesThePanelKeyOnceThePromptWindowIsGone()
    async throws
  {
    let (rig, apps) = try Self.rig()
    rig.controller.show(inVisible: rig.screen.visible, makeKey: true)
    let made = rig.key.made
    let composer = try await Self.compose(rig)
    let folder = TempFolder()
    try Self.pasteFile(rig, in: folder)
    apps.activate(Apps.folderPrompt)
    Self.loseKey(rig)
    await rig.fixture.input.pasteRead?.value
    #expect(rig.controller.isShown)
    apps.activate(Apps.finder)
    #expect(rig.controller.isShown)
    #expect(!rig.controller.isKey)
    apps.close(Apps.folderPrompt)
    await apps.runChecks(after: 1)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { rig.controller.isKey })
    #expect(rig.controller.isShown)
    #expect(rig.key.made == made + 1)
    Self.expectKept(rig, composer)
    Self.finish(rig, composer)
  }

  @Test func aPasteThatCausesAFolderPromptMakesThePanelKeyAgainAfterTheAnswer() throws {
    let (rig, apps) = try Self.rig()
    rig.controller.show(inVisible: rig.screen.visible, makeKey: true)
    let done = rig.controller.holdThroughPrompt(apps.returns)
    apps.activate(Apps.folderPrompt)
    Self.loseKey(rig)
    #expect(rig.controller.isShown)
    apps.answerFolderPrompt()
    #expect(rig.controller.isShown)
    #expect(!rig.controller.isKey)
    done()
    #expect(rig.controller.isShown)
    #expect(rig.controller.isKey)
    #expect(rig.key.made == 2)
    rig.controller.hide()
  }

  @Test func choosingAnotherAppWhileAPastePromptIsUpHidesThePanelAsBefore() async throws {
    let (rig, apps) = try Self.rig()
    rig.controller.show(inVisible: rig.screen.visible, makeKey: true)
    let done = rig.controller.holdThroughPrompt(apps.returns)
    apps.activate(Apps.folderPrompt)
    Self.loseKey(rig)
    #expect(rig.controller.isShown)
    apps.activate(Apps.editor)
    #expect(rig.controller.isShown)
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { apps.checks.waits == 1 })
    await apps.runChecks(after: 1)
    #expect(!rig.controller.isShown)
    apps.close(Apps.folderPrompt)
    done()
    apps.activate(Apps.finder)
    #expect(!rig.controller.isShown)
    #expect(rig.key.made == 1)
  }

  @Test func withKeepOpenThePanelTakesTheKeyBackAfterAPromptButNotAfterAChoice() async throws {
    let (rig, apps) = try Self.rig(keepOpen: true)
    rig.controller.show(inVisible: rig.screen.visible, makeKey: true)
    let first = rig.controller.holdThroughPrompt(apps.returns)
    apps.activate(Apps.folderPrompt)
    Self.loseKey(rig)
    apps.answerFolderPrompt()
    first()
    #expect(rig.controller.isKey)
    #expect(rig.key.made == 2)
    let second = rig.controller.holdThroughPrompt(apps.returns)
    apps.activate(Apps.folderPrompt)
    Self.loseKey(rig)
    apps.activate(Apps.editor)
    await apps.runChecks(after: 1)
    apps.close(Apps.folderPrompt)
    second()
    apps.activate(Apps.finder)
    #expect(rig.controller.isShown)
    #expect(!rig.controller.isKey)
    #expect(rig.key.made == 2)
    rig.controller.hide()
  }

  @Test func aKeyLossDuringAReadWithNoPromptHidesThePanelWhenTheReadLands() throws {
    let (rig, apps) = try Self.rig()
    rig.controller.show(inVisible: rig.screen.visible, makeKey: true)
    let done = rig.controller.holdThroughPrompt(apps.returns)
    Self.loseKey(rig)
    #expect(rig.controller.isShown)
    done()
    #expect(!rig.controller.isShown)
    #expect(rig.key.made == 1)
  }

  @Test func aPanelThatIsNotKeyHoldsNothing() throws {
    let (rig, apps) = try Self.rig()
    rig.controller.show(inVisible: rig.screen.visible, makeKey: false)
    let done = rig.controller.holdThroughPrompt(apps.returns)
    apps.activate(Apps.folderPrompt)
    Self.loseKey(rig)
    #expect(!rig.controller.isShown)
    apps.answerFolderPrompt()
    done()
    #expect(!rig.controller.isShown)
    #expect(rig.key.made == 0)
  }

  @Test func aPasteAndADropWatchTheirFileReadsUntilTheyLand() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
    let log = Log()
    fixture.input.hooks = FrontReturn.Hooks(read: {
      log.events.append("start")
      return { log.events.append("end") }
    })
    let folder = TempFolder()
    let file = try FileReadThreadTests.file(named: "Orange block.png", in: folder)
    try InputModelTests.fill(board, file: file, text: "Orange block.png", image: false)
    #expect(fixture.input.takeImage(from: board))
    #expect(log.events == ["start"])
    await fixture.input.pasteRead?.value
    #expect(log.events == ["start", "end"])
    #expect(fixture.input.attachment != nil)
    #expect(fixture.input.drop(board))
    #expect(log.events == ["start", "end", "start"])
    #expect(await PanelHarness.waitUntil(within: .seconds(2)) { log.events.count == 4 })
    #expect(log.events == ["start", "end", "start", "end"])
    #expect(try fixture.store.entries().compactMap(\.thought).count == 1)
  }
}

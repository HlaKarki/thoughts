import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized, .throwaway)
struct AppVisibilityTests {
  @MainActor
  final class HiddenApp {
    var hidden: Bool
    var unhides = 0

    init(hidden: Bool) {
      self.hidden = hidden
    }

    var visibility: AppVisibility {
      AppVisibility(
        isHidden: { self.hidden },
        unhide: {
          self.hidden = false
          self.unhides += 1
        })
    }

    func hideAgain() {
      hidden = true
    }
  }

  static let screen = PreviewPlacementTests.offscreen(CGSize(width: 1728, height: 1117))

  static func preferences() throws -> Preferences {
    Preferences(
      defaults: try Throwaway.defaults())
  }

  @Test func onlyAHiddenAppIsUnhidden() {
    let hidden = HiddenApp(hidden: true)
    hidden.visibility.revealBeforeOrderingFront()
    #expect(hidden.unhides == 1)
    #expect(!hidden.hidden)
    hidden.visibility.revealBeforeOrderingFront()
    #expect(hidden.unhides == 1)
    let shown = HiddenApp(hidden: false)
    shown.visibility.revealBeforeOrderingFront()
    #expect(shown.unhides == 0)
  }

  @Test func showingThePanelUnhidesAHiddenApp() async throws {
    let app = HiddenApp(hidden: true)
    let screen = Self.screen
    let controller = PanelController(
      content: NSView(), preferences: try Self.preferences(), screens: { [screen] },
      visibility: app.visibility)
    controller.show(inVisible: screen.visible, makeKey: false)
    #expect(app.unhides == 1)
    #expect(controller.isShown)
    controller.hide()
    #expect(!controller.isShown)
    app.hideAgain()
    controller.show(inVisible: screen.visible, makeKey: false)
    #expect(app.unhides == 2)
    controller.hide()
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func showingAChipUnhidesAHiddenAppEvenWhenTheChipIsAlreadyUp() async throws {
    let app = HiddenApp(hidden: true)
    let visible = Self.screen.visible
    var fronted = 0
    let chip = EdgeChipPanel(
      edge: { .right }, visibleFrame: { _ in visible }, orderFront: { _ in fronted += 1 },
      visibility: app.visibility)
    chip.show(HintChipView(kind: .nothingToSave))
    #expect(app.unhides == 1)
    #expect(fronted == 1)
    app.hideAgain()
    chip.show(HintChipView(kind: .nothingToSave))
    #expect(app.unhides == 2)
    chip.hide()
    try? await Task.sleep(for: .milliseconds(400))
    #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
  }

  @Test func showingThePreviewUnhidesAHiddenApp() async throws {
    let app = HiddenApp(hidden: true)
    let fixture = try ListFixture()
    let shot = try fixture.addScreenshot(note: "note", daysAgo: 0.3)
    try fixture.reload()
    let screen = Self.screen
    let anchor = PanelController.frame(in: screen.visible, edge: .right)
    let preview = PreviewWindowController(
      list: fixture.model, anchor: { (anchor, .right) }, screens: { [screen] },
      visibility: app.visibility)
    fixture.model.onPreviewChange = { preview.update(showing: $0) }
    fixture.model.select(shot.file.lastPathComponent, extend: false)
    fixture.model.perform(.preview)
    #expect(app.unhides == 1)
    #expect(preview.alpha == 1)
    try await PreviewPlacementTests.close(preview, fixture)
  }

  @Test func startingADragUnhidesAHiddenAppBeforeTheDropZoneAppears() throws {
    let app = HiddenApp(hidden: true)
    let board = Throwaway.pasteboard()
    var handler: (@MainActor (NSEvent.EventType) -> Void)?
    let monitor = DragSessionMonitor(
      pasteboard: board,
      install: { _, run in
        handler = run
        return "global"
      }, installLocal: { _, _ in nil }, remove: { _ in })
    let screen = Self.screen
    let preferences = try Self.preferences()
    let controller = PanelController(
      content: NSView(), preferences: preferences, screens: { [screen] },
      visibility: app.visibility)
    var fronted: [NSWindow] = []
    let zone = EdgeDropZone(
      panel: controller, preferences: preferences, monitor: monitor, visibility: app.visibility,
      orderFront: { fronted.append($0) })
    zone.start()
    handler?(.leftMouseDown)
    board.clearContents()
    board.setString("x", forType: .string)
    handler?(.leftMouseDragged)
    #expect(app.unhides == 1)
    #expect(fronted.count == 1)
    handler?(.leftMouseUp)
    monitor.stop()
  }
}

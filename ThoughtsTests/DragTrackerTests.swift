import AppKit
import Testing

@testable import Thoughts

@MainActor
struct DragTrackerTests {
  @Test func aDragNeedsAPasteboardChangeAndEndsOnMouseUp() {
    var tracker = DragTracker(baseline: 10)
    #expect(tracker.handle(.down, changeCount: 10) == nil)
    #expect(tracker.handle(.dragged, changeCount: 10) == nil)
    #expect(!tracker.isActive)
    #expect(tracker.handle(.up, changeCount: 10) == nil)
    #expect(tracker.handle(.down, changeCount: 10) == nil)
    #expect(tracker.handle(.dragged, changeCount: 11) == .began)
    #expect(tracker.handle(.dragged, changeCount: 11) == nil)
    #expect(tracker.isActive)
    #expect(tracker.handle(.up, changeCount: 11) == .ended)
    #expect(tracker.handle(.dragged, changeCount: 11) == nil)
  }

  @Test func theMonitorReportsStartAndEndFromInjectedEvents() {
    let board = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally() }
    var handler: (@MainActor (NSEvent.EventType) -> Void)?
    var localHandler: (@MainActor (NSEvent.EventType) -> Void)?
    var removed = 0
    let monitor = DragSessionMonitor(
      pasteboard: board,
      install: { _, run in
        handler = run
        return "global"
      },
      installLocal: { _, run in
        localHandler = run
        return "local"
      },
      remove: { _ in removed += 1 })
    var log: [String] = []
    monitor.onStart = { log.append("start") }
    monitor.onEnd = { log.append("end") }
    monitor.start()
    handler?(.leftMouseDown)
    board.clearContents()
    board.setString("x", forType: .string)
    handler?(.leftMouseDragged)
    handler?(.leftMouseDragged)
    #expect(monitor.isDragging)
    handler?(.leftMouseUp)
    #expect(log == ["start", "end"])
    handler?(.leftMouseDown)
    board.clearContents()
    board.setString("y", forType: .string)
    handler?(.leftMouseDragged)
    localHandler?(.leftMouseUp)
    #expect(log == ["start", "end", "start", "end"])
    monitor.stop()
    #expect(removed == 2)
  }

  @Test func theZoneHugsTheScreenEdgeOnThePanelSide() {
    let screen = CGRect(x: 0, y: 0, width: 1600, height: 900)
    let visible = CGRect(x: 0, y: 0, width: 1600, height: 875)
    let right = EdgeDropZone.frame(screen: screen, visible: visible, edge: .right)
    #expect(right == CGRect(x: 1594, y: 0, width: 6, height: 875))
    let left = EdgeDropZone.frame(screen: screen, visible: visible, edge: .left)
    #expect(left == CGRect(x: 0, y: 0, width: 6, height: 875))
  }
}

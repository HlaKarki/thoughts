import Foundation
import ThoughtsCore

@MainActor
final class SourceRecorder {
  private let tracker: FrontmostTracker
  private let ax: AXReader

  init(tracker: FrontmostTracker, ax: AXReader) {
    self.tracker = tracker
    self.ax = ax
  }

  func current() -> Source {
    guard
      let app = SourceRule.app(
        frontmost: tracker.frontmost, history: tracker.history, ownBundleID: tracker.ownBundleID)
    else { return Source() }
    var source = Source(app: app.name, bundleID: app.bundleID)
    if let page = ax.page(pid: app.pid, bundleID: app.bundleID ?? "") {
      source.url = page.url
      source.title = page.title
      source.window = page.title
    } else {
      source.window = ax.focusedWindowTitle(pid: app.pid)
    }
    return source
  }
}

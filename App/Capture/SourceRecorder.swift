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

  func current() async -> Source {
    guard
      let app = SourceRule.app(
        frontmost: tracker.frontmost, history: tracker.history, ownBundleID: tracker.ownBundleID)
    else { return Source() }
    var source = Source(app: app.name, bundleID: app.bundleID)
    let ax = ax
    let read = await Task.detached {
      if let page = ax.page(pid: app.pid, bundleID: app.bundleID ?? "") {
        return (window: page.title, url: page.url, title: page.title)
      }
      return (window: ax.focusedWindowTitle(pid: app.pid), url: URL?.none, title: String?.none)
    }.value
    source.window = read.window
    source.url = read.url
    source.title = read.title
    return source
  }
}

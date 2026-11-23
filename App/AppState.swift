import AppKit
import SwiftUI
import ThoughtsCore

@MainActor
final class AppState {
  let location: StorageLocation
  let index: SearchIndex
  let live: LiveIndex
  let preferences: Preferences
  let panel: PanelController
  private var summon: Task<Void, Never>?

  init(preferences: Preferences = Preferences()) throws {
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Thoughts"
    let location = StorageLocation(appName: appName)
    let folder = try location.resolve()
    self.location = location
    self.index = try SearchIndex(url: location.indexURL, folder: folder)
    self.live = LiveIndex(location: location, index: index, recognizer: VisionTextRecognizer())
    self.preferences = preferences
    let content = NSHostingView(rootView: PanelRootView(preferences: preferences))
    content.sizingOptions = []
    self.panel = PanelController(content: content, preferences: preferences)
    summon = SummonShortcut.listen { [panel] in panel.toggle() }
  }

  func stop() {
    summon?.cancel()
    live.stop()
  }
}

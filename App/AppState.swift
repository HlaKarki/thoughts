import AppKit
import SwiftUI
import ThoughtsCore

@MainActor
final class AppState {
  let location: StorageLocation
  let index: SearchIndex
  let live: LiveIndex
  let list: ListModel
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
    let list = ListModel(index: index, live: live, location: location)
    self.list = list
    let content = NSHostingView(rootView: PanelRootView(preferences: preferences, list: list))
    content.sizingOptions = []
    let panel = PanelController(content: content, preferences: preferences)
    self.panel = panel
    panel.onWillShow = { [list] in
      list.focus = .input
      list.selection = []
      list.now = Date()
      list.panelDidShow()
    }
    panel.onWillHide = { [list] in list.panelDidHide() }
    list.onCommand = { [panel] command in
      if command == .hidePanel { panel.hide() }
    }
    list.start()
    summon = SummonShortcut.listen { [panel] in panel.toggle() }
  }

  func stop() {
    summon?.cancel()
    live.stop()
  }
}

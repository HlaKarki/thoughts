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
  let actions: ThoughtActions
  let pasteboard: PasteboardWriter
  let preview: PreviewWindowController
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
    let pasteboard = PasteboardWriter()
    self.pasteboard = pasteboard
    let actions = ThoughtActions(list: list, location: location, pasteboard: pasteboard)
    self.actions = actions
    let preview = PreviewWindowController(list: list) { [panel] in
      panel.isShown ? (panel.frame, panel.edge) : nil
    }
    self.preview = preview
    list.onPreviewChange = { [preview] thought in preview.update(showing: thought) }
    panel.onWillShow = { [list] in
      list.focus = .input
      list.selection = []
      list.now = Date()
      list.panelDidShow()
    }
    panel.onWillHide = { [list, preview] in
      list.panelDidHide()
      preview.hide()
    }
    list.onCommand = { [panel, actions] command in
      if command == .hidePanel { panel.hide() }
      actions.perform(command)
    }
    list.start()
    summon = SummonShortcut.listen { [panel] in panel.toggle() }
  }

  func stop() {
    summon?.cancel()
    live.stop()
  }
}

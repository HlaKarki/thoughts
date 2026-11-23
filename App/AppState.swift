import AppKit
import SwiftUI
import ThoughtsCore

@MainActor
final class AppState {
  let location: StorageLocation
  let index: SearchIndex
  let live: LiveIndex
  let list: ListModel
  let input: InputModel
  let dragMonitor: DragSessionMonitor
  let dropZone: EdgeDropZone
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
    let input = InputModel(location: location) { [list] in list.showHint($0) }
    self.input = input
    let hosting = NSHostingView(
      rootView: PanelRootView(preferences: preferences, list: list, input: input))
    hosting.sizingOptions = []
    let content = DropDestinationView(content: hosting)
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
      list.focus = list.editing == nil ? .input : .edit
      if list.editing == nil { list.selection = [] }
      list.now = Date()
      list.panelDidShow()
    }
    let monitor = DragSessionMonitor()
    let zone = EdgeDropZone(panel: panel, preferences: preferences, monitor: monitor)
    dragMonitor = monitor
    dropZone = zone
    zone.onTargetChange = { [input] in input.isDropTargeted = $0 }
    zone.onDrop = { [input] in input.drop($0) }
    content.onEnter = { [input] in input.isDropTargeted = true }
    content.onExit = { [input] in input.isDropTargeted = false }
    content.onDrop = { [input, zone, panel] pasteboard in
      zone.noteDrop()
      panel.makeKey()
      return input.drop(pasteboard)
    }
    panel.onPaste = { [list, input] pasteboard in
      list.focus == .input && input.takeImage(from: pasteboard)
    }
    panel.onWillHide = { [list, preview, input] in
      list.panelDidHide()
      preview.hide()
      input.isDropTargeted = false
    }
    list.onCommand = { [panel, actions, input] command in
      switch command {
      case .hidePanel: panel.hide()
      case .add: Task { await input.submit() }
      case .removeAttachment: input.removeAttachment()
      default: break
      }
      actions.perform(command)
    }
    zone.start()
    list.start()
    summon = SummonShortcut.listen { [panel] in panel.toggle() }
  }

  func stop() {
    summon?.cancel()
    dragMonitor.stop()
    live.stop()
  }
}

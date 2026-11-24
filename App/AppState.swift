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
  let entry: PanelEntry
  let actions: ThoughtActions
  let pasteboard: PasteboardWriter
  let preview: PreviewWindowController
  let capture: CaptureCoordinator
  let chip: EdgeChipPanel
  let gesture: GestureMonitor
  let captureShortcut: CaptureShortcut
  let clipboard: ClipboardWatcher
  let offers: OfferCenter
  let settings: SettingsWindowController
  let firstRun: FirstRunWindowController
  let importer: InboxImporter?
  let urls: URLHandler
  let updater: Updater
  let menuBar: MenuBarController
  let shared: SharedMenuItems
  private var summon: Task<Void, Never>?
  private var captureTask: Task<Void, Never>?
  private var acceptTask: Task<Void, Never>?
  private var offerChipShown = false

  private final class Trigger {
    var fire: () -> Void = {}
  }

  init(preferences: Preferences = Preferences()) throws {
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Thoughts"
    let location = StorageLocation(appName: appName)
    self.location = location
    self.index = try Self.index(for: location)
    self.live = LiveIndex(location: location, index: index, recognizer: VisionTextRecognizer())
    self.preferences = preferences
    let list = ListModel(index: index, live: live, location: location)
    self.list = list
    let tracker = FrontmostTracker(ownBundleID: Bundle.main.bundleIdentifier ?? "")
    tracker.start()
    let ax = AXReader()
    let recorder = SourceRecorder(tracker: tracker, ax: ax)
    let input = InputModel(location: location) { [list] in list.tell($0) }
    input.source = {
      let source = await recorder.current()
      return source == Source() ? nil : source
    }
    self.input = input
    let openSettings = Trigger()
    let updater = Updater()
    self.updater = updater
    let shared = SharedMenuItems(
      updates: updater.item, openSettings: { openSettings.fire() },
      checkForUpdates: { updater.checkForUpdates() })
    self.shared = shared
    let hosting = NSHostingView(
      rootView: PanelRootView(preferences: preferences, list: list, input: input, shared: shared))
    hosting.sizingOptions = []
    let content = DropDestinationView(content: hosting)
    let panel = PanelController(content: content, preferences: preferences)
    self.panel = panel
    let entry = PanelEntry(panel)
    self.entry = entry
    let menuBarMenu = MenuBarMenu(shared: shared)
    let menuBar = MenuBarController(
      preferences: preferences, updates: updater.item,
      surface: SystemStatusItem(menu: menuBarMenu.menu), menu: menuBarMenu,
      showPanel: { entry.fromMenu(on: $0) })
    self.menuBar = menuBar
    menuBarMenu.onOpened = { [panel] in panel.ownMenuOpened() }
    menuBarMenu.onClosed = { [panel] in panel.ownMenuClosed($0) }
    panel.ownIconInUse = { [menuBar] in menuBar.ownIconInUse(event: NSApp.currentEvent) }
    menuBar.start()
    let pasteboard = PasteboardWriter()
    self.pasteboard = pasteboard
    let actions = ThoughtActions(
      list: list, location: location, pasteboard: pasteboard, undoManager: panel.undoManager)
    self.actions = actions
    panel.onNothingToDo = { [actions] in actions.nothingToDo($0) }
    panel.defersHistory = { [actions] in actions.deferIfBusy($0) }
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
    let chip = EdgeChipPanel(
      edge: { [panel] in panel.edge },
      shownPanelFrame: { [panel] in panel.isShown ? panel.restingFrame : nil })
    self.chip = chip
    let sound = SavedSound(preferences: preferences)
    let clipboard = ClipboardWatcher(
      isOwnChange: { [pasteboard] in pasteboard.ownChangeCounts.contains($0) },
      frontmost: { tracker.frontmost.flatMap { $0.bundleID == tracker.ownBundleID ? nil : $0 } },
      ownWindowIsKey: { NSApp.keyWindow != nil })
    self.clipboard = clipboard
    let screenshots = ScreenshotFolderWatcher(storageFolder: { [location] in
      try? location.configuredFolder()
    })
    let offers = OfferCenter(
      preferences: preferences, input: input, clipboard: clipboard, screenshots: screenshots,
      sound: sound,
      source: {
        let source = await recorder.current()
        return source == Source() ? nil : source
      })
    self.offers = offers
    pasteboard.onOwnChange = { [offers] in offers.noteOwn($0) }
    input.onManualSave = { [offers] in
      offers.noteSaved(changeCount: $0.pasteboardChangeCount, file: $0.sourceFile)
    }
    let capture = CaptureCoordinator(
      frontmost: { tracker.frontmost }, ownBundleID: tracker.ownBundleID,
      ownWindowIsKey: { NSApp.keyWindow != nil },
      reader: SelectionReader(readSelection: { ax.selection(pid: $0) }),
      source: { await recorder.current() }, input: input,
      writer: pasteboard, sound: sound,
      currentOffer: { offers.current?.id },
      acceptOffer: { try await offers.accept() },
      clipboardCopy: { clipboard.lastCopy })
    self.capture = capture
    clipboard.isPaused = { [capture] in capture.isCapturing }
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
      case .type(let text): input.text += text
      default: break
      }
      actions.perform(command)
    }
    zone.start()
    list.start()
    let gesture = GestureMonitor(preferences: preferences)
    let services = SystemServices.live
    let moving = StorageMover.moving(location: location, index: index, live: live)
    let choosing = StorageMover.choosing(location: location, index: index, live: live)
    let gate = OfferGate(firstRunDone: { preferences.firstRunDone }, start: { offers.start() })
    let settings = SettingsWindowController {
      let model = SettingsModel(
        preferences: preferences, services: services, login: .live, storage: moving)
      model.onStorageRepointed = { [list] in list.storageRepointed() }
      return model
    }
    self.settings = settings
    openSettings.fire = { settings.show() }
    firstRun = FirstRunWindowController {
      let model = FirstRunModel(
        preferences: preferences, services: services, storage: choosing)
      model.onAccessibilityGranted = { gesture.reinstall() }
      model.onFinish = {
        gate.firstRunFinished()
        panel.show()
      }
      return model
    }
    let shortcut = CaptureShortcut(preferences: preferences)
    self.gesture = gesture
    captureShortcut = shortcut
    let save: (NewThought) async throws -> Void = { [input] in
      try await input.save($0, pasteboardChangeCount: nil)
    }
    let importer = InboxImporter.groupInbox().map { [input] in
      InboxImporter(inbox: $0, save: save, source: { await input.source() })
    }
    self.importer = importer
    urls = URLHandler(
      panel: panel, importer: importer, save: save, source: { [input] in await input.source() })
    gesture.onGesture = { [weak self] in self?.gestureFired() }
    gesture.start()
    shortcut.onFire = { [weak self] in self?.gestureFired() }
    shortcut.start()
    offers.onChange = { [weak self] offer, thumbnail in self?.present(offer, thumbnail: thumbnail) }
    importer?.onFailure = { [weak self] in self?.showFailure($0) }
    urls.onFailure = { [weak self] in self?.showFailure($0) }
    importer?.start()
    clipboard.start()
    gate.launch()
    summon = SummonShortcut.listen { entry.summon() }
  }

  static func index(for location: StorageLocation) throws -> SearchIndex {
    try SearchIndex(url: location.indexURL, folder: location.configuredFolder())
  }

  private func gestureFired() {
    guard !capture.isCapturing else { return }
    captureTask = Task { [capture, weak self] in
      let outcome = await capture.capture()
      await self?.showFeedback(for: outcome)
    }
  }

  private func showFeedback(for outcome: CaptureOutcome) async {
    switch outcome {
    case .saved(let thought), .acceptedOffer(let thought):
      if !panel.isShown {
        showHint(.saved(await SavedPreview.load(thought)))
      }
    case .alreadySaved(let thought):
      var preview = SavedPreview.withoutThought
      if let thought { preview = await SavedPreview.load(thought) }
      showHint(.alreadySaved(preview))
    case .nothingToSave:
      showHint(.nothingToSave)
    case .failed(let message):
      showHint(.failed(message))
    }
  }

  private func showFailure(_ message: String) {
    showHint(.failed(message))
  }

  private func showHint(_ kind: HintChipView.Kind) {
    offerChipShown = false
    chip.show(HintChipView(kind: kind), hideAfter: kind.lifetime)
  }

  private func present(_ offer: Offer?, thumbnail: NSImage?) {
    guard let offer else {
      guard offerChipShown else { return }
      offerChipShown = false
      chip.hide()
      return
    }
    offerChipShown = true
    chip.show(
      OfferChipView(
        kind: offer.file == nil ? .clipboard : .file, thumbnail: thumbnail,
        keycap: preferences.captureMethod.keycap),
      onClick: { [weak self] in self?.acceptByClick() })
  }

  private func acceptByClick() {
    acceptTask = Task { [offers, weak self] in
      do {
        let thought = try await offers.accept()
        await self?.showFeedback(for: .acceptedOffer(thought))
      } catch {
        await self?.showFeedback(for: .failed(CaptureCoordinator.message(for: error)))
      }
    }
  }

  func stop() {
    summon?.cancel()
    menuBar.stop()
    captureTask?.cancel()
    acceptTask?.cancel()
    gesture.stop()
    captureShortcut.stop()
    offers.stop()
    importer?.stop()
    chip.hide()
    dragMonitor.stop()
    live.stop()
  }
}

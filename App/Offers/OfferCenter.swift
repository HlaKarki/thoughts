import AppKit
import Observation
import ThoughtsCore

@MainActor
final class OfferCenter {
  private var queue = OfferQueue()
  private let preferences: Preferences
  private let input: InputModel
  private let pasteboard: NSPasteboard
  private let clipboard: ClipboardWatcher
  private let screenshots: ScreenshotFolderWatcher
  private let location: ScreenshotLocation
  private let source: @MainActor () async -> Source?
  private let sound: SavedSound
  private let accessBehavior: @MainActor () -> NSPasteboard.AccessBehavior
  private let now: () -> Date
  private let notifications: NotificationCenter
  private var shortcutObserver: (any NSObjectProtocol)?
  private var chain: Task<Void, Never>?
  private var expiry: Task<Void, Never>?
  private var started = false

  private(set) var thumbnail: NSImage?
  var onChange: (Offer?, NSImage?) -> Void = { _, _ in }

  init(
    preferences: Preferences,
    input: InputModel,
    clipboard: ClipboardWatcher,
    screenshots: ScreenshotFolderWatcher,
    sound: SavedSound,
    source: @escaping @MainActor () async -> Source?,
    pasteboard: NSPasteboard = .general,
    location: ScreenshotLocation = ScreenshotLocation(),
    accessBehavior: (@MainActor () -> NSPasteboard.AccessBehavior)? = nil,
    now: @escaping () -> Date = Date.init,
    notifications: NotificationCenter = .default
  ) {
    self.preferences = preferences
    self.input = input
    self.clipboard = clipboard
    self.screenshots = screenshots
    self.sound = sound
    self.source = source
    self.pasteboard = pasteboard
    self.location = location
    self.accessBehavior = accessBehavior ?? { [pasteboard] in pasteboard.accessBehavior }
    self.now = now
    self.notifications = notifications
  }

  var current: Offer? { queue.current }

  func start() {
    guard !started else { return }
    started = true
    clipboard.onSignal = { [weak self] in self?.receive($0) }
    screenshots.onFile = { [weak self] file, date in self?.receive(.file(file, at: date)) }
    clipboard.start()
    applyPreferences()
    track()
    shortcutObserver = notifications.addObserver(
      forName: .captureShortcutChanged, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.shortcutChanged() }
    }
  }

  func stop() {
    started = false
    shortcutObserver.map(notifications.removeObserver)
    shortcutObserver = nil
    clipboard.stop()
    screenshots.stop()
    chain?.cancel()
    expiry?.cancel()
    chain = nil
    expiry = nil
  }

  func noteSaved(changeCount: Int?, file: URL?) {
    let before = queue.current?.id
    var file = file
    if let saved = file, let offered = queue.current?.file,
      ScreenshotFolderWatcher.key(saved) == ScreenshotFolderWatcher.key(offered)
    {
      file = offered
    }
    queue.noteSaved(changeCount: changeCount, file: file, at: now())
    dropIfGone(was: before)
  }

  func noteOwn(_ changeCount: Int) {
    let before = queue.current?.id
    queue.noteOwn(changeCount: changeCount)
    dropIfGone(was: before)
  }

  func accept() async throws -> Thought {
    guard let offer = queue.take() else {
      throw ThoughtsError.io(String(localized: "That offer expired"))
    }
    clear()
    let content: NewContent
    var recorded = offer.source
    if let file = offer.file, FileManager.default.fileExists(atPath: file.path) {
      var withFile = offer.source ?? Source()
      withFile.file = file.path
      recorded = withFile
      content = .image(.file(file), note: "")
    } else if let changeCount = offer.changeCount {
      guard pasteboard.changeCount == changeCount else { throw ThoughtsError.clipboardChanged }
      guard !ClipboardWatcher.isExcluded(pasteboard.types ?? []) else {
        throw ThoughtsError.io(String(localized: "The clipboard no longer holds an image"))
      }
      let found = await PasteboardRead(pasteboard: pasteboard).run {
        CaptureCoordinator.image(in: $0)
      }
      guard let image = found else {
        throw ThoughtsError.io(
          accessBehavior() == .alwaysAllow
            ? String(localized: "The clipboard no longer holds an image")
            : CaptureCoordinator.pasteRefusedMessage)
      }
      guard pasteboard.changeCount == changeCount else { throw ThoughtsError.clipboardChanged }
      content = .image(image, note: "")
    } else {
      throw ThoughtsError.io(String(localized: "That screenshot isn't there anymore"))
    }
    let new = NewThought(content: content, source: recorded, created: now())
    let thought = try await input.save(new, pasteboardChangeCount: offer.changeCount)
    queue.noteSaved(changeCount: offer.changeCount, file: offer.file, at: now())
    sound.play()
    return thought
  }

  func folders() -> [URL] {
    var seen = Set<String>()
    return ([location.folder] + preferences.watchedFolders).filter {
      seen.insert(ScreenshotFolderWatcher.key($0)).inserted
    }
  }

  func storageRepointed() {
    guard started else { return }
    applyPreferences()
  }

  private func applyPreferences() {
    screenshots.update(folders: preferences.offersEnabled ? folders() : [])
    if !preferences.offersEnabled, queue.current != nil {
      _ = queue.take()
      clear()
    }
  }

  private func shortcutChanged() {
    guard started, case .shortcut = preferences.captureMethod, queue.current != nil else { return }
    onChange(queue.current, thumbnail)
  }

  private func method(changedFrom method: CaptureMethod) {
    guard preferences.captureMethod != method, queue.current != nil else { return }
    onChange(queue.current, thumbnail)
  }

  private func track() {
    let before = preferences.captureMethod
    withObservationTracking {
      _ = preferences.offersEnabled
      _ = preferences.watchedFolders
      _ = preferences.captureMethod
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self, self.started else { return }
        self.applyPreferences()
        self.method(changedFrom: before)
        self.track()
      }
    }
  }

  func receive(_ signal: OfferSignal) {
    guard preferences.offersEnabled else { return }
    let recorded = Task { [source] in await source() }
    let previous = chain
    chain = Task { [weak self] in
      await previous?.value
      let source = await recorded.value
      await self?.apply(signal, source: source == Source() ? nil : source)
    }
  }

  private func apply(_ signal: OfferSignal, source: Source?) async {
    guard preferences.offersEnabled else { return }
    let update = queue.add(signal, source: source)
    let offer: Offer
    switch update {
    case .ignore:
      return
    case .show(let shown):
      offer = shown
      thumbnail = nil
    case .update(let updated):
      offer = updated
    }
    if case .file = signal {
      thumbnail = await Self.thumbnail(file: offer.file)
    } else if case .show = update {
      thumbnail = await clipboardThumbnail(for: offer)
    }
    guard queue.current?.id == offer.id else { return }
    onChange(queue.current, thumbnail)
    scheduleExpiry()
  }

  private func clipboardThumbnail(for offer: Offer) async -> NSImage? {
    guard accessBehavior() == .alwaysAllow, let changeCount = offer.changeCount,
      pasteboard.changeCount == changeCount
    else { return nil }
    if let file = offer.file ?? ClipboardWatcher.imageFile(in: pasteboard) {
      return await OfferThumbnail.make(file: file)
    }
    guard PasteboardReader.fileURLs(in: pasteboard).isEmpty,
      let found = PasteboardReader.imageData(in: pasteboard)
    else { return nil }
    return await OfferThumbnail.make(data: found.data)
  }

  private static func thumbnail(file: URL?) async -> NSImage? {
    guard let file else { return nil }
    return await OfferThumbnail.make(file: file)
  }

  private func scheduleExpiry() {
    expiry?.cancel()
    guard let offer = queue.current else { return }
    let wait = max(0, queue.lifetime - now().timeIntervalSince(offer.updated))
    expiry = Task { [weak self] in
      try? await Task.sleep(for: .seconds(wait))
      guard !Task.isCancelled, let self else { return }
      if self.queue.expire(now: self.now()) {
        self.clear()
      } else {
        self.scheduleExpiry()
      }
    }
  }

  private func dropIfGone(was id: OfferID?) {
    guard id != nil, queue.current?.id != id else { return }
    clear()
  }

  private func clear() {
    expiry?.cancel()
    thumbnail = nil
    onChange(nil, nil)
  }
}

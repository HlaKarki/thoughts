import AppKit
import ThoughtsCore
import UniformTypeIdentifiers

@MainActor
final class ClipboardWatcher {
  static let interval: Duration = .milliseconds(500)

  private let pasteboard: NSPasteboard
  private let accessBehavior: @MainActor () -> NSPasteboard.AccessBehavior
  private let isOwnChange: @MainActor (Int) -> Bool
  private let contentType: @MainActor () async -> UTType?
  private let now: () -> Date
  private let frontmost: @MainActor () -> AppSnapshot?
  private let ownWindowIsKey: @MainActor () -> Bool
  private let notifications: NotificationCenter
  private var lastCount: Int
  private var task: Task<Void, Never>?
  private var classifying: Task<Void, Never>?
  private var keyObservers: [NSObjectProtocol] = []
  private var ownWindowKey = false
  private var lastKeyWindow: ObjectIdentifier?

  private(set) var lastCopy: ClipboardCopy?
  var isPaused: @MainActor () -> Bool = { false }
  var onSignal: (OfferSignal) -> Void = { _ in }

  init(
    pasteboard: NSPasteboard = .general,
    accessBehavior: (@MainActor () -> NSPasteboard.AccessBehavior)? = nil,
    isOwnChange: @escaping @MainActor (Int) -> Bool = { _ in false },
    contentType: (@MainActor () async -> UTType?)? = nil,
    now: @escaping () -> Date = Date.init,
    frontmost: @escaping @MainActor () -> AppSnapshot? = { nil },
    ownWindowIsKey: @escaping @MainActor () -> Bool = { false },
    notifications: NotificationCenter = .default
  ) {
    self.pasteboard = pasteboard
    self.accessBehavior = accessBehavior ?? { [pasteboard] in pasteboard.accessBehavior }
    self.isOwnChange = isOwnChange
    self.contentType =
      contentType ?? { [pasteboard] in await PasteboardDetect.contentType(of: pasteboard) }
    self.now = now
    self.frontmost = frontmost
    self.ownWindowIsKey = ownWindowIsKey
    self.notifications = notifications
    self.lastCount = pasteboard.changeCount
  }

  func start() {
    watchKeyWindows()
    guard task == nil else { return }
    lastCount = pasteboard.changeCount
    task = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: Self.interval)
        guard !Task.isCancelled else { return }
        self?.poll()
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
    for observer in keyObservers { notifications.removeObserver(observer) }
    keyObservers = []
  }

  func watchKeyWindows() {
    guard keyObservers.isEmpty else { return }
    ownWindowKey = ownWindowIsKey()
    lastKeyWindow = nil
    keyObservers = [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification].map {
      name in
      notifications.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
        let window = note.object.map { ObjectIdentifier($0 as AnyObject) }
        MainActor.assumeIsolated { self?.keyWindowChanged(name, window: window) }
      }
    }
  }

  private func keyWindowChanged(_ name: Notification.Name, window: ObjectIdentifier?) {
    let becameKey = name == NSWindow.didBecomeKeyNotification
    poll(ownWindowWasKey: becameKey ? ownWindowKey : true)
    if becameKey {
      ownWindowKey = true
      lastKeyWindow = window
    } else if lastKeyWindow == nil || lastKeyWindow == window {
      ownWindowKey = false
      lastKeyWindow = nil
    }
  }

  func poll() {
    poll(ownWindowWasKey: ownWindowIsKey())
  }

  private func poll(ownWindowWasKey: Bool) {
    guard !isPaused(), let change = record(ownWindowWasKey: ownWindowWasKey) else { return }
    classifying = Task { await classify(change.copy, own: change.ownChange) }
  }

  @discardableResult
  func pollNow() async -> Int {
    let polled = lastCount
    guard let change = record(ownWindowWasKey: ownWindowIsKey()) else {
      await classifying?.value
      return polled
    }
    await classify(change.copy, own: change.ownChange)
    return polled
  }

  private func record(ownWindowWasKey: Bool) -> (copy: ClipboardCopy, ownChange: Bool)? {
    let count = pasteboard.changeCount
    guard count != lastCount else { return nil }
    lastCount = count
    let ownChange = isOwnChange(count)
    let copy = ClipboardCopy(
      changeCount: count, seen: now(), kind: .unknown, app: frontmost(),
      own: ownChange || ownWindowWasKey)
    if accessBehavior() != .alwaysAllow {
      lastCopy = copy
    }
    return (copy, ownChange)
  }

  func classify(_ copy: ClipboardCopy, own: Bool) async {
    let allowed = accessBehavior() == .alwaysAllow
    var isImage = false
    var kind: ClipboardCopy.Kind?
    if allowed {
      let types = pasteboard.types ?? []
      if Self.isExcluded(types) {
        kind = nil
      } else if types.contains(.fileURL) {
        let type = await contentType()
        isImage =
          type.map { $0.conforms(to: .image) } ?? (Self.imageFile(in: pasteboard) != nil)
        kind = isImage ? .image : nil
      } else if types.contains(where: Self.isImageType) {
        isImage = true
        kind = .image
      } else if types.contains(where: Self.isTextType) {
        kind = .text
      }
    } else {
      let type = await contentType()
      isImage = type?.conforms(to: .image) == true
      if isImage {
        kind = .image
      } else if let type {
        kind = type.conforms(to: .text) ? .text : nil
      } else {
        kind = .unknown
      }
    }
    guard pasteboard.changeCount == copy.changeCount else { return }
    lastCopy = kind.map {
      ClipboardCopy(
        changeCount: copy.changeCount, seen: copy.seen, kind: $0, app: copy.app, own: copy.own)
    }
    if isImage, !own {
      onSignal(.clipboard(changeCount: copy.changeCount, file: nil, at: copy.seen))
    }
  }

  static func isExcluded(_ types: [NSPasteboard.PasteboardType]) -> Bool {
    ClipboardTypes.isExcluded(types.map(\.rawValue))
  }

  static func isImageType(_ type: NSPasteboard.PasteboardType) -> Bool {
    UTType(type.rawValue)?.conforms(to: .image) == true
  }

  static func isTextType(_ type: NSPasteboard.PasteboardType) -> Bool {
    UTType(type.rawValue)?.conforms(to: .text) == true
  }

  static func imageFile(in pasteboard: NSPasteboard) -> URL? {
    PasteboardReader.fileURLs(in: pasteboard).first {
      UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true
    }
  }
}

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
  private var lastCount: Int
  private var task: Task<Void, Never>?

  private(set) var lastImage: ClipboardImage?
  var isPaused: @MainActor () -> Bool = { false }
  var onSignal: (OfferSignal) -> Void = { _ in }

  init(
    pasteboard: NSPasteboard = .general,
    accessBehavior: (@MainActor () -> NSPasteboard.AccessBehavior)? = nil,
    isOwnChange: @escaping @MainActor (Int) -> Bool = { _ in false },
    contentType: (@MainActor () async -> UTType?)? = nil,
    now: @escaping () -> Date = Date.init
  ) {
    self.pasteboard = pasteboard
    self.accessBehavior = accessBehavior ?? { [pasteboard] in pasteboard.accessBehavior }
    self.isOwnChange = isOwnChange
    self.contentType =
      contentType ?? { [pasteboard] in await PasteboardDetect.contentType(of: pasteboard) }
    self.now = now
    self.lastCount = pasteboard.changeCount
  }

  func start() {
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
  }

  func poll() {
    guard !isPaused() else { return }
    let count = pasteboard.changeCount
    guard count != lastCount else { return }
    lastCount = count
    let seen = now()
    let own = isOwnChange(count)
    if accessBehavior() != .alwaysAllow {
      lastImage = ClipboardImage(changeCount: count, seen: seen)
    }
    Task { await classify(count: count, seen: seen, own: own) }
  }

  func classify(count: Int, seen: Date, own: Bool) async {
    let allowed = accessBehavior() == .alwaysAllow
    var isImage = false
    var knownNotImage = false
    if allowed {
      let types = pasteboard.types ?? []
      if types.contains(.fileURL) {
        let type = await contentType()
        isImage =
          type.map { $0.conforms(to: .image) } ?? (Self.imageFile(in: pasteboard) != nil)
      } else {
        isImage = types.contains(where: Self.isImageType)
      }
      knownNotImage = !isImage
    } else {
      let type = await contentType()
      isImage = type?.conforms(to: .image) == true
      knownNotImage = type != nil && !isImage
    }
    guard pasteboard.changeCount == count else { return }
    if isImage || (!allowed && !knownNotImage) {
      lastImage = ClipboardImage(changeCount: count, seen: seen)
    } else {
      lastImage = nil
    }
    if isImage, !own {
      onSignal(.clipboard(changeCount: count, file: nil, at: seen))
    }
  }

  static func isImageType(_ type: NSPasteboard.PasteboardType) -> Bool {
    UTType(type.rawValue)?.conforms(to: .image) == true
  }

  static func imageFile(in pasteboard: NSPasteboard) -> URL? {
    PasteboardReader.fileURLs(in: pasteboard).first {
      UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true
    }
  }
}

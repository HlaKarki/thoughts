import CoreServices
import Foundation

struct WatchEvent: Sendable, Equatable {
  let url: URL
  let forcesFullScan: Bool
}

public final class FolderWatcher: @unchecked Sendable {
  private final class Context {
    let root: String
    let lock = NSRecursiveLock()
    var cancelled = false
    var handler: @Sendable ([WatchEvent]) -> Void

    init(root: String, handler: @escaping @Sendable ([WatchEvent]) -> Void) {
      self.root = root
      self.handler = handler
    }

    func deliver(_ events: [WatchEvent]) {
      lock.lock()
      defer { lock.unlock() }
      guard !cancelled, !events.isEmpty else { return }
      handler(events)
    }

    func cancel() {
      lock.lock()
      cancelled = true
      handler = { _ in }
      lock.unlock()
    }
  }

  private static let fullScanFlags = FSEventStreamEventFlags(
    kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped
      | kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagRootChanged)

  private let folder: URL
  private let latency: TimeInterval
  private let queue: DispatchQueue
  private let handler: @Sendable ([WatchEvent]) -> Void
  private let lifecycle = NSLock()
  private var stream: FSEventStreamRef?
  private var context: Context?

  public convenience init(
    folder: URL, latency: TimeInterval = 0.2, queue: DispatchQueue,
    onChange: @escaping @Sendable ([URL]) -> Void
  ) {
    self.init(folder: folder, latency: latency, queue: queue) { events in
      onChange(events.map(\.url))
    }
  }

  init(
    folder: URL, latency: TimeInterval, queue: DispatchQueue,
    onEvents: @escaping @Sendable ([WatchEvent]) -> Void
  ) {
    self.folder = folder
    self.latency = latency
    self.queue = queue
    self.handler = onEvents
  }

  deinit {
    stop()
  }

  public func start() throws {
    lifecycle.lock()
    defer { lifecycle.unlock() }
    guard stream == nil else { return }
    let root = Self.canonicalPath(folder)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root, isDirectory: &isDirectory),
      isDirectory.boolValue
    else { throw ThoughtsError.storageUnavailable(folder.path) }

    let context = Context(root: root, handler: handler)
    var streamContext = FSEventStreamContext(
      version: 0,
      info: Unmanaged.passRetained(context).toOpaque(),
      retain: nil,
      release: { info in
        guard let info else { return }
        Unmanaged<Context>.fromOpaque(info).release()
      },
      copyDescription: nil)
    let flags = FSEventStreamCreateFlags(
      kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagUseCFTypes)
    guard
      let created = FSEventStreamCreate(
        kCFAllocatorDefault, Self.callback, &streamContext, [root] as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags)
    else {
      Unmanaged.passUnretained(context).release()
      throw ThoughtsError.io("The folder can't be watched")
    }
    FSEventStreamSetDispatchQueue(created, queue)
    guard FSEventStreamStart(created) else {
      FSEventStreamInvalidate(created)
      FSEventStreamRelease(created)
      throw ThoughtsError.io("The folder can't be watched")
    }
    stream = created
    self.context = context
  }

  public func stop() {
    lifecycle.lock()
    let stream = self.stream
    let context = self.context
    self.stream = nil
    self.context = nil
    lifecycle.unlock()
    guard let stream, let context else { return }
    context.cancel()
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
  }

  static func canonicalPath(_ url: URL) -> String {
    guard let resolved = realpath(url.path, nil) else { return url.standardized.path }
    defer { free(resolved) }
    return String(cString: resolved)
  }

  private static let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
    guard let info else { return }
    let context = Unmanaged<Context>.fromOpaque(info).takeUnretainedValue()
    let list = unsafeBitCast(paths, to: CFArray.self) as? [String] ?? []
    var events: [WatchEvent] = []
    for index in 0..<min(count, list.count) {
      let path = list[index]
      let forced = flags[index] & fullScanFlags != 0
      let url = URL(fileURLWithPath: path)
      if !forced {
        if path == context.root || url.lastPathComponent.hasPrefix(".") { continue }
      }
      events.append(WatchEvent(url: url, forcesFullScan: forced))
    }
    context.deliver(events)
  }
}

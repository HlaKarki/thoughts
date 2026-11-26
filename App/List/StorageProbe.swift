import AppKit
import ThoughtsCore

struct StorageProbe: Sendable {
  var folder: @Sendable () -> URL?
  var exists: @Sendable (URL) -> Bool
  var restart: @Sendable () throws -> Void

  static func live(location: StorageLocation, live: LiveIndex) -> Self {
    Self(
      folder: { try? location.configuredFolder() },
      exists: { FileManager.default.fileExists(atPath: $0.path) },
      restart: { try live.restart() })
  }
}

struct MountSignal {
  var observe: @MainActor (@escaping @MainActor () -> Void) -> Void

  static let live = MountSignal { handler in
    let names = [
      NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification,
      NSWorkspace.didRenameVolumeNotification,
    ]
    for name in names {
      NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
        _ in
        MainActor.assumeIsolated { handler() }
      }
    }
  }
}

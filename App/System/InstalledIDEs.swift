import Foundation
import Observation
import ThoughtsCore

enum InstalledApplications {
  static func folders(home: URL) -> [URL] {
    [
      URL(fileURLWithPath: "/Applications", isDirectory: true),
      home.appendingPathComponent("Applications", isDirectory: true),
      home.appendingPathComponent("Applications/JetBrains Toolbox", isDirectory: true),
    ]
  }

  static func bundleIDs(in folders: [URL]) -> [String] {
    folders.flatMap { folder in
      let children =
        (try? FileManager.default.contentsOfDirectory(
          at: folder, includingPropertiesForKeys: nil)) ?? []
      return children.filter { $0.pathExtension == "app" }
        .compactMap { Bundle(url: $0)?.bundleIdentifier }
    }
  }
}

@MainActor
@Observable
final class InstalledIDEs {
  private(set) var hasJetBrains = false

  func scan(folders: [URL]) async {
    let ids = await Task.detached(priority: .utility) {
      InstalledApplications.bundleIDs(in: folders)
    }.value
    hasJetBrains = JetBrainsIDE.isAny(ids)
  }
}

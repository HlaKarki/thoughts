import AppKit
import ThoughtsCore

struct SourceOpener {
  var openURL: @MainActor (URL) -> Bool
  var launchApp: @MainActor (String) -> Bool
  var reveal: @MainActor ([URL]) -> Void
  var exists: @MainActor (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }

  static let live = SourceOpener(
    openURL: { NSWorkspace.shared.open($0) },
    launchApp: { bundleID in
      guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
      else { return false }
      NSWorkspace.shared.openApplication(
        at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
      return true
    },
    reveal: { NSWorkspace.shared.activateFileViewerSelecting($0) }
  )

  static func canOpen(_ source: Source?) -> Bool {
    guard let source else { return false }
    return source.url != nil || nonEmpty(source.bundleID) != nil || nonEmpty(source.file) != nil
  }

  @MainActor
  @discardableResult
  func open(_ source: Source?) -> Bool {
    guard let source else { return false }
    if let url = source.url, openURL(url) { return true }
    if let bundleID = Self.nonEmpty(source.bundleID), launchApp(bundleID) { return true }
    if let path = Self.nonEmpty(source.file) {
      let file = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
      guard FileManager.default.fileExists(atPath: file.path) else { return false }
      reveal([file])
      return true
    }
    return false
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }
}

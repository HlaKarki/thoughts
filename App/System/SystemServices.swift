import AppKit
import ApplicationServices

struct SystemServices: Sendable {
  static let accessibilityPane = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
  static let pasteboardPane = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard")!

  var accessibilityTrusted: @MainActor () -> Bool
  var requestAccessibility: @MainActor () -> Void
  var open: @MainActor (URL) -> Void
  var reveal: @MainActor (URL) -> Void
  var pasteboardAccess: @MainActor () -> NSPasteboard.AccessBehavior
  var chooseFolder: @MainActor (_ message: String, _ start: URL?) async -> URL?
  var readFolder: @Sendable (URL) -> Void

  static var accessibilityPaneName: String {
    if #available(macOS 27, *) {
      String(localized: "Device Control and Data Access")
    } else {
      String(localized: "Accessibility")
    }
  }

  static let live = SystemServices(
    accessibilityTrusted: { AXIsProcessTrusted() },
    requestAccessibility: {
      _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    },
    open: { NSWorkspace.shared.open($0) },
    reveal: { NSWorkspace.shared.activateFileViewerSelecting([$0]) },
    pasteboardAccess: { NSPasteboard.general.accessBehavior },
    chooseFolder: { message, start in
      let panel = NSOpenPanel()
      panel.canChooseDirectories = true
      panel.canChooseFiles = false
      panel.canCreateDirectories = true
      panel.allowsMultipleSelection = false
      panel.message = message
      panel.prompt = String(localized: "Choose")
      panel.directoryURL = start
      return panel.runModal() == .OK ? panel.url : nil
    },
    readFolder: { _ = try? FileManager.default.contentsOfDirectory(atPath: $0.path) })
}

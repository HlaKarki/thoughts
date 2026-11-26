import Foundation

struct ScreenshotLocation {
  static let domain = "com.apple.screencapture"
  static let key = "location"

  private let defaults: UserDefaults?
  private let home: URL
  private let isFolder: (URL) -> Bool

  init(
    defaults: UserDefaults? = UserDefaults(suiteName: ScreenshotLocation.domain),
    home: URL = FileManager.default.homeDirectoryForCurrentUser,
    isFolder: @escaping (URL) -> Bool = ScreenshotLocation.folderExists
  ) {
    self.defaults = defaults
    self.home = home
    self.isFolder = isFolder
  }

  var desktop: URL {
    home.appendingPathComponent("Desktop", isDirectory: true)
  }

  var folder: URL {
    guard let configured = defaults?.string(forKey: Self.key), !configured.isEmpty else {
      return desktop
    }
    let url = expand(configured)
    return isFolder(url) ? url : desktop
  }

  private func expand(_ path: String) -> URL {
    var expanded = path
    if path == "~" {
      expanded = home.path
    } else if path.hasPrefix("~/") {
      expanded = home.path + path.dropFirst()
    }
    return URL(fileURLWithPath: expanded, isDirectory: true).standardized
  }

  func observe(_ onChange: @escaping @MainActor @Sendable () -> Void) -> ScreenshotLocationObserver?
  {
    defaults.map { ScreenshotLocationObserver(defaults: $0, onChange: onChange) }
  }

  static func folderExists(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }
}

final class ScreenshotLocationObserver: NSObject {
  private let defaults: UserDefaults
  private let onChange: @MainActor @Sendable () -> Void

  init(defaults: UserDefaults, onChange: @escaping @MainActor @Sendable () -> Void) {
    self.defaults = defaults
    self.onChange = onChange
    super.init()
    defaults.addObserver(self, forKeyPath: ScreenshotLocation.key, options: [], context: nil)
  }

  deinit {
    defaults.removeObserver(self, forKeyPath: ScreenshotLocation.key)
  }

  override func observeValue(
    forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    let onChange = onChange
    Task { @MainActor in onChange() }
  }
}

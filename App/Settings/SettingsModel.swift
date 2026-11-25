import AppKit
import Observation

@MainActor
@Observable
final class SettingsModel {
  let preferences: Preferences
  let home: URL
  private(set) var loginStatus: LoginStatus
  private(set) var loginError: String?
  private(set) var storageFolder: URL
  private(set) var storageError: String?
  private(set) var storageMissing = false
  private(set) var isMoving = false
  private(set) var watchedFolderNote: String?
  private(set) var clipboardAccess: NSPasteboard.AccessBehavior
  var selectedFolder: URL?
  @ObservationIgnored private let services: SystemServices
  @ObservationIgnored private let login: LoginControl
  @ObservationIgnored private let storage: StorageMover
  @ObservationIgnored private let screenshots: ScreenshotLocation
  @ObservationIgnored var onStorageRepointed: @MainActor () -> Void = {}

  init(
    preferences: Preferences,
    services: SystemServices,
    login: LoginControl,
    storage: StorageMover,
    screenshots: ScreenshotLocation = ScreenshotLocation(),
    home: URL = FileManager.default.homeDirectoryForCurrentUser
  ) {
    self.preferences = preferences
    self.services = services
    self.login = login
    self.storage = storage
    self.screenshots = screenshots
    self.home = home
    loginStatus = login.status()
    storageFolder = (try? storage.current()) ?? home.appendingPathComponent("Thoughts")
    clipboardAccess = services.pasteboardAccess()
    storageMissing = !storage.exists(storageFolder)
  }

  var storageText: String { PathText.abbreviated(storageFolder, home: home) }

  var screenshotFolder: URL { screenshots.folder }

  var loginIsOn: Bool { loginStatus != .off }

  var removableSelection: URL? {
    guard let selected = selectedFolder else { return nil }
    return preferences.watchedFolders.first { Self.same($0, selected) }
  }

  func refresh() {
    loginStatus = login.status()
    clipboardAccess = services.pasteboardAccess()
    readStorage()
  }

  private func readStorage() {
    storageFolder = (try? storage.current()) ?? storageFolder
    storageMissing = !storage.exists(storageFolder)
  }

  func setLogin(_ enabled: Bool) {
    do {
      try login.set(enabled)
      loginError = nil
    } catch {
      loginError = error.localizedDescription
    }
    loginStatus = login.status()
  }

  func openLoginSettings() {
    login.openSettings()
  }

  func openClipboardSettings() {
    services.open(SystemServices.pasteboardPane)
  }

  func showStorageInFinder() {
    services.reveal(storageFolder)
  }

  func addWatchedFolder() async {
    let message = String(localized: "Choose a folder to watch for new images")
    guard let folder = await services.chooseFolder(message, screenshotFolder) else { return }
    let known = [screenshotFolder] + preferences.watchedFolders
    if let existing = known.first(where: { Self.same($0, folder) }) {
      if Self.same(existing, screenshotFolder) {
        watchedFolderNote = String(localized: "Screenshots are already watched")
      } else {
        watchedFolderNote = String(localized: "That folder is already watched")
        selectedFolder = existing
      }
      return
    }
    watchedFolderNote = nil
    preferences.watchedFolders.append(folder)
    selectedFolder = folder
  }

  func removeSelectedFolder() {
    guard let target = removableSelection else { return }
    preferences.watchedFolders.removeAll { Self.same($0, target) }
    selectedFolder = nil
    watchedFolderNote = nil
  }

  func moveStorage() async {
    guard !isMoving else { return }
    let message = String(localized: "Choose a new folder for your thoughts")
    guard let target = await services.chooseFolder(message, storageFolder) else { return }
    isMoving = true
    defer { isMoving = false }
    do {
      storageFolder = try await storage.perform(to: target)
      storageError = nil
      storageMissing = !storage.exists(storageFolder)
      onStorageRepointed()
    } catch {
      readStorage()
      storageError = StorageMover.message(for: error)
    }
  }

  static func same(_ first: URL, _ second: URL) -> Bool {
    first.standardized.path == second.standardized.path
  }
}

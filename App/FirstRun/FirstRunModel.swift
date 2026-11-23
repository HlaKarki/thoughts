import AppKit
import KeyboardShortcuts
import Observation

@MainActor
@Observable
final class FirstRunModel {
  let preferences: Preferences
  let home: URL
  private(set) var step: FirstRunStep = .summonKey
  private(set) var state: FirstRunState
  private(set) var storageFolder: URL
  private(set) var storageError: String?
  private(set) var isChangingStorage = false
  private(set) var accessibilityRequested = false
  private(set) var clipboardAccess: NSPasteboard.AccessBehavior
  @ObservationIgnored private let services: SystemServices
  @ObservationIgnored private let screenshots: ScreenshotLocation
  @ObservationIgnored private let storage: StorageMover
  @ObservationIgnored private let poller: PermissionPoller
  @ObservationIgnored private let captureShortcutText: @MainActor () -> String?
  @ObservationIgnored var onAccessibilityGranted: @MainActor () -> Void = {}
  @ObservationIgnored var onFinish: @MainActor () -> Void = {}

  init(
    preferences: Preferences,
    services: SystemServices,
    storage: StorageMover,
    screenshots: ScreenshotLocation = ScreenshotLocation(),
    home: URL = FileManager.default.homeDirectoryForCurrentUser,
    pollInterval: Duration = .seconds(1),
    summonKeySet: @MainActor () -> Bool = { KeyboardShortcuts.getShortcut(for: .summon) != nil },
    captureShortcutText: @escaping @MainActor () -> String? = { CaptureMethod.captureShortcutText }
  ) {
    self.preferences = preferences
    self.services = services
    self.storage = storage
    self.screenshots = screenshots
    self.home = home
    self.captureShortcutText = captureShortcutText
    poller = PermissionPoller(isTrusted: services.accessibilityTrusted, interval: pollInterval)
    state = FirstRunState(
      summonKeySet: summonKeySet(), accessibilityGranted: services.accessibilityTrusted(),
      captureReady: !preferences.captureShortcut || captureShortcutText() != nil)
    storageFolder = (try? storage.current()) ?? home.appendingPathComponent("Thoughts")
    clipboardAccess = services.pasteboardAccess()
  }

  var canContinue: Bool {
    FirstRunFlow.next(after: step, state: state) != step
  }

  var captureKeycap: KeycapContent? {
    preferences.captureMethod.keycap(shortcut: captureShortcutText())
  }

  var storageText: String { PathText.abbreviated(storageFolder, home: home) }

  var watchedFolders: [URL] {
    var seen = Set<String>()
    return ([screenshots.folder] + preferences.watchedFolders).filter {
      seen.insert($0.standardized.path).inserted
    }
  }

  var showsClipboardPromptNote: Bool { clipboardAccess != .alwaysAllow }

  func summonKeyChanged(_ shortcut: KeyboardShortcuts.Shortcut?) {
    state.summonKeySet = shortcut != nil
  }

  func captureChanged() {
    state.captureReady = !preferences.captureShortcut || captureShortcutText() != nil
  }

  func advance() {
    if step == .clipboard {
      preferences.firstRunDone = true
      onFinish()
      return
    }
    let target = FirstRunFlow.next(after: step, state: state)
    guard target != step else { return }
    enter(target)
  }

  func back() {
    let target = FirstRunFlow.previous(before: step)
    guard target != step else { return }
    step = target
  }

  func openAccessibility() {
    if accessibilityRequested {
      services.open(SystemServices.accessibilityPane)
    } else {
      accessibilityRequested = true
      services.requestAccessibility()
    }
  }

  func watchAccessibility() async {
    guard !state.accessibilityGranted else { return }
    await poller.waitForAccessibility()
    guard services.accessibilityTrusted(), !state.accessibilityGranted else { return }
    state.accessibilityGranted = true
    onAccessibilityGranted()
  }

  func changeStorage() async {
    guard !isChangingStorage else { return }
    let message = String(localized: "Choose where thoughts are saved")
    guard let target = await services.chooseFolder(message, storageFolder) else { return }
    isChangingStorage = true
    defer { isChangingStorage = false }
    do {
      storageFolder = try await storage.perform(to: target)
      storageError = nil
    } catch {
      storageFolder = (try? storage.current()) ?? storageFolder
      storageError = StorageMover.message(for: error)
    }
  }

  private func enter(_ target: FirstRunStep) {
    step = target
    switch target {
    case .clipboard:
      clipboardAccess = services.pasteboardAccess()
      for folder in watchedFolders { services.readFolder(folder) }
    default:
      break
    }
  }
}

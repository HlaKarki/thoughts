import AppKit
import SwiftUI

@main
struct ThoughtsApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var state: AppState?
  private var launchURLs: [URL] = []

  static var runsUnderTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
      || NSClassFromString("XCTestCase") != nil
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard !Self.runsUnderTests else { return }
    do {
      let state = try AppState()
      self.state = state
      let kind = LaunchKind.current(openedURLs: !launchURLs.isEmpty)
      switch LaunchAction.decide(firstRunDone: state.preferences.firstRunDone, kind: kind) {
      case .firstRun: state.firstRun.show()
      case .showPanel: state.panel.show()
      case .nothing: break
      }
      state.urls.handle(launchURLs)
      launchURLs = []
    } catch {
      let alert = NSAlert()
      alert.messageText = String(localized: "Thoughts can't start")
      alert.informativeText = error.localizedDescription
      alert.runModal()
      NSApp.terminate(nil)
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    guard let state else {
      launchURLs += urls
      return
    }
    state.urls.handle(urls)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    state?.panel.show()
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    state?.stop()
  }
}

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

  static var runsUnderTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
      || NSClassFromString("XCTestCase") != nil
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard !Self.runsUnderTests else { return }
    do {
      state = try AppState()
    } catch {
      let alert = NSAlert()
      alert.messageText = String(localized: "Thoughts can't start")
      alert.informativeText = error.localizedDescription
      alert.runModal()
      NSApp.terminate(nil)
    }
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

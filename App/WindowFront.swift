import AppKit

@MainActor
struct WindowFront {
  var visibility: AppVisibility = .live
  var activateIgnoringOtherApps: @MainActor () -> Void = { NSApp.activate(ignoringOtherApps: true) }
  var makeKey: @MainActor (NSWindow) -> Void = { $0.makeKeyAndOrderFront(nil) }
  var orderFrontRegardless: @MainActor (NSWindow) -> Void = { $0.orderFrontRegardless() }
  var isShown: @MainActor (NSWindow) -> Bool = { $0.isVisible }

  static let live = WindowFront()

  func bring(_ window: NSWindow) {
    activateIgnoringOtherApps()
    visibility.revealBeforeOrderingFront()
    makeKey(window)
    orderFrontRegardless(window)
  }

  func bringIfShown(_ window: NSWindow) {
    guard isShown(window) else { return }
    bring(window)
  }
}

import AppKit

@MainActor
struct WindowFront {
  var visibility: AppVisibility = .live
  var activateIgnoringOtherApps: @MainActor () -> Void = { NSApp.activate(ignoringOtherApps: true) }
  var makeKey: @MainActor (NSWindow) -> Void = { $0.makeKeyAndOrderFront(nil) }
  var orderFrontRegardless: @MainActor (NSWindow) -> Void = { $0.orderFrontRegardless() }

  static let live = WindowFront()

  func bring(_ window: NSWindow) {
    activateIgnoringOtherApps()
    visibility.revealBeforeOrderingFront()
    makeKey(window)
    orderFrontRegardless(window)
  }
}

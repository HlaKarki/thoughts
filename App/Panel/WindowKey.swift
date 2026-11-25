import AppKit

@MainActor
struct WindowKey {
  var isKey: @MainActor (NSWindow) -> Bool = { $0.isKeyWindow }
  var makeKey: @MainActor (NSWindow) -> Void = { $0.makeKeyAndOrderFront(nil) }

  static let live = WindowKey()
}

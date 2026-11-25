import AppKit

@MainActor
struct AppVisibility {
  var isHidden: @MainActor () -> Bool = { NSApp.isHidden }
  var unhide: @MainActor () -> Void = { NSApp.unhideWithoutActivation() }

  static let live = AppVisibility()

  func revealBeforeOrderingFront() {
    if isHidden() { unhide() }
  }
}

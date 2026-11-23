import AppKit

@MainActor
protocol StatusItemSurface: AnyObject {
  var isVisible: Bool { get set }
  var onRemoved: (@MainActor () -> Void)? { get set }
  var screen: NSScreen? { get }
  func isOwnClick(_ event: NSEvent?) -> Bool
  func present(updateWaiting: Bool, label: String)
}

@MainActor
final class SystemStatusItem: StatusItemSurface {
  static let autosaveName = "ThoughtsMenuBar"

  var onRemoved: (@MainActor () -> Void)?
  private let item: NSStatusItem
  private let dot = UpdateDotView()
  private var observation: NSKeyValueObservation?
  private var changing = false

  init(menu: NSMenu, statusBar: NSStatusBar = .system) {
    item = statusBar.statusItem(withLength: MenuBarGlyph.buttonLength(updateWaiting: false))
    item.behavior = .removalAllowed
    item.autosaveName = Self.autosaveName
    item.menu = menu
    if let button = item.button {
      button.imagePosition = .imageOnly
      button.imageScaling = .scaleNone
      MenuBarGlyph.install(dot: dot, in: button)
    }
    dot.isHidden = true
    observation = item.observe(\.isVisible, options: [.new]) { [weak self] _, change in
      MainActor.assumeIsolated {
        guard let self, !self.changing, change.newValue == false else { return }
        self.onRemoved?()
      }
    }
  }

  var isVisible: Bool {
    get { item.isVisible }
    set {
      changing = true
      item.isVisible = newValue
      changing = false
    }
  }

  var screen: NSScreen? { item.button?.window?.screen }

  func isOwnClick(_ event: NSEvent?) -> Bool {
    guard let event, let window = item.button?.window, event.window === window else {
      return false
    }
    return event.type == .leftMouseDown || event.type == .rightMouseDown
  }

  func present(updateWaiting: Bool, label: String) {
    guard let button = item.button else { return }
    item.length = MenuBarGlyph.buttonLength(updateWaiting: updateWaiting)
    button.image = MenuBarGlyph.image(updateWaiting: updateWaiting)
    button.setAccessibilityLabel(label)
    dot.isHidden = !updateWaiting
    MenuBarGlyph.place(dot: dot, in: button)
  }
}

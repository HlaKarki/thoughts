import AppKit
import Testing

enum KeyWindowSeam {
  private static let selector = NSSelectorFromString("_keyWindow")
  private static let activeSelector = NSSelectorFromString("_hasActiveAppearance")
  nonisolated(unsafe) private static var original: IMP?
  nonisolated(unsafe) private static var originalActive: IMP?
  nonisolated(unsafe) private static var window: NSWindow?

  private typealias Getter = @convention(c) (AnyObject, Selector) -> Unmanaged<NSWindow>?
  private typealias Flag = @convention(c) (AnyObject, Selector) -> Bool

  @MainActor
  static func install(_ target: NSWindow) throws {
    let method = try #require(class_getInstanceMethod(NSApplication.self, selector))
    let active = try #require(class_getInstanceMethod(type(of: target), activeSelector))
    window = target
    guard original == nil else { return }
    original = method_getImplementation(method)
    let block: @convention(block) (AnyObject) -> AnyObject? = { _ in window }
    method_setImplementation(method, imp_implementationWithBlock(block))
    let activeOriginal = method_getImplementation(active)
    originalActive = activeOriginal
    let flag = unsafeBitCast(activeOriginal, to: Flag.self)
    let activeBlock: @convention(block) (AnyObject) -> Bool = { this in
      this === window || flag(this, activeSelector)
    }
    method_setImplementation(active, imp_implementationWithBlock(activeBlock))
  }

  @MainActor
  static func remove() {
    let target = window
    window = nil
    if let originalActive, let target,
      let active = class_getInstanceMethod(type(of: target), activeSelector)
    {
      method_setImplementation(active, originalActive)
      self.originalActive = nil
    }
    guard let original, let method = class_getInstanceMethod(NSApplication.self, selector)
    else { return }
    method_setImplementation(method, original)
    self.original = nil
  }

  @MainActor
  static var appKitKeyWindow: NSWindow? {
    guard let method = class_getInstanceMethod(NSApplication.self, selector) else { return nil }
    let getter = unsafeBitCast(original ?? method_getImplementation(method), to: Getter.self)
    return getter(NSApp, selector)?.takeUnretainedValue()
  }
}

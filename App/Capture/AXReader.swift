import ApplicationServices
import Foundation

@MainActor
final class AXReader {
  private static let messagingTimeout: Float = 0.25
  private static let searchBudget: TimeInterval = 0.4
  private static let searchDepth = 14
  private static let searchLimit = 1500

  func focusedWindowTitle(pid: Int32) -> String? {
    guard AXIsProcessTrusted(), let window = focusedWindow(pid: pid) else { return nil }
    return BrowserPages.title(attribute(kAXTitleAttribute, of: window))
  }

  func page(pid: Int32, bundleID: String) -> (url: URL?, title: String?)? {
    guard AXIsProcessTrusted(), let window = focusedWindow(pid: pid),
      let webArea = findWebArea(in: window)
    else { return nil }
    let url = BrowserPages.url(
      webArea: attribute(kAXURLAttribute, of: webArea),
      document: attribute(kAXDocumentAttribute, of: window))
    return (url, BrowserPages.title(attribute(kAXTitleAttribute, of: window)))
  }

  private func focusedWindow(pid: Int32) -> AXUIElement? {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, Self.messagingTimeout)
    guard let value = attribute(kAXFocusedWindowAttribute, of: app),
      CFGetTypeID(value as CFTypeRef) == AXUIElementGetTypeID()
    else { return nil }
    return (value as! AXUIElement)
  }

  private func findWebArea(in window: AXUIElement) -> AXUIElement? {
    let deadline = Date().addingTimeInterval(Self.searchBudget)
    var level = [window]
    var visited = 0
    for _ in 0..<Self.searchDepth {
      var next: [AXUIElement] = []
      for element in level {
        visited += 1
        if visited > Self.searchLimit || Date() > deadline { return nil }
        if attribute(kAXRoleAttribute, of: element) as? String == "AXWebArea" { return element }
        if let children = attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] {
          next.append(contentsOf: children)
        }
      }
      if next.isEmpty { return nil }
      level = next
    }
    return nil
  }

  private func attribute(_ name: String, of element: AXUIElement) -> AnyObject? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
      return nil
    }
    return value
  }
}

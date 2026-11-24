import ApplicationServices
import Foundation
import ThoughtsCore

final class AXReader: Sendable {
  private static let messagingTimeout: Float = 0.25
  private static let searchBudget: TimeInterval = 0.4
  private static let searchDepth = 14
  private static let searchLimit = 1500

  init() {
    AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), Self.messagingTimeout)
  }

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

  func selection(pid: Int32) -> SelectionProbe {
    guard AXIsProcessTrusted() else { return .unavailable }
    let app = SystemAXNode(element: AXUIElementCreateApplication(pid))
    let deadline = Date().addingTimeInterval(Self.searchBudget)
    let inspector = SelectionInspector(expired: { Date() > deadline })
    return inspector.probe(
      focused: app.node(kAXFocusedUIElementAttribute),
      menuBar: { app.node(kAXMenuBarAttribute) })
  }

  private func focusedWindow(pid: Int32) -> AXUIElement? {
    let app = AXUIElementCreateApplication(pid)
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
        let (role, children) = roleAndChildren(of: element)
        if role == "AXWebArea" { return element }
        if BrowserPages.canContainPage(role: role) { next.append(contentsOf: children) }
      }
      if next.isEmpty { return nil }
      level = next
    }
    return nil
  }

  private func roleAndChildren(of element: AXUIElement) -> (String?, [AXUIElement]) {
    let attributes = [kAXRoleAttribute, kAXChildrenAttribute] as CFArray
    var values: CFArray?
    let status = AXUIElementCopyMultipleAttributeValues(
      element, attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
    guard status == .success, let list = values as? [Any], list.count == 2 else { return (nil, []) }
    return (list[0] as? String, list[1] as? [AXUIElement] ?? [])
  }

  private func attribute(_ name: String, of element: AXUIElement) -> AnyObject? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
      return nil
    }
    return value
  }
}

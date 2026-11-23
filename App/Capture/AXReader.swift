import ApplicationServices
import Carbon.HIToolbox
import Foundation
import ThoughtsCore

final class AXReader: Sendable {
  private static let messagingTimeout: Float = 0.25
  private static let searchBudget: TimeInterval = 0.4
  private static let searchDepth = 14
  private static let searchLimit = 1500

  private let secureInput: @Sendable () -> Bool

  init(secureInput: @escaping @Sendable () -> Bool = { IsSecureEventInputEnabled() }) {
    self.secureInput = secureInput
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
    if secureInput() { return .secureField }
    guard AXIsProcessTrusted(), let element = focusedElement(pid: pid) else { return .unavailable }
    if isSecure(element) { return .secureField }
    var answered = false
    let plain = attribute(kAXSelectedTextAttribute, of: element) as? String
    if let plain {
      if !plain.isEmpty { return .text(plain) }
      answered = true
    }
    if let marked = markedSelection(of: element) {
      if !marked.isEmpty { return .text(marked) }
      answered = true
    }
    return answered ? .empty : .unavailable
  }

  private func focusedElement(pid: Int32) -> AXUIElement? {
    let app = AXUIElementCreateApplication(pid)
    guard let value = attribute(kAXFocusedUIElementAttribute, of: app),
      CFGetTypeID(value as CFTypeRef) == AXUIElementGetTypeID()
    else { return nil }
    return (value as! AXUIElement)
  }

  private func isSecure(_ element: AXUIElement) -> Bool {
    let secure = "AXSecureTextField"
    return [kAXRoleAttribute, kAXSubroleAttribute].contains {
      attribute($0, of: element) as? String == secure
    }
  }

  private func markedSelection(of element: AXUIElement) -> String? {
    guard let range = attribute("AXSelectedTextMarkerRange", of: element) else { return nil }
    var text: CFTypeRef?
    let status = AXUIElementCopyParameterizedAttributeValue(
      element, "AXStringForTextMarkerRange" as CFString, range, &text)
    guard status == .success else { return nil }
    return text as? String
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

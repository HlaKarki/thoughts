import ApplicationServices
import Foundation

protocol AXNode {
  func string(_ attribute: String) -> String?
  func integer(_ attribute: String) -> Int?
  func flag(_ attribute: String) -> Bool?
  func node(_ attribute: String) -> (any AXNode)?
  func nodes(_ attribute: String) -> [any AXNode]
  func markedSelection() -> String?
}

struct SystemAXNode: AXNode {
  let element: AXUIElement

  func string(_ attribute: String) -> String? {
    value(attribute) as? String
  }

  func integer(_ attribute: String) -> Int? {
    (value(attribute) as? NSNumber)?.intValue
  }

  func flag(_ attribute: String) -> Bool? {
    guard let number = value(attribute) as? NSNumber,
      CFGetTypeID(number) == CFBooleanGetTypeID()
    else { return nil }
    return number.boolValue
  }

  func node(_ attribute: String) -> (any AXNode)? {
    guard let found = value(attribute), CFGetTypeID(found as CFTypeRef) == AXUIElementGetTypeID()
    else { return nil }
    return SystemAXNode(element: found as! AXUIElement)
  }

  func nodes(_ attribute: String) -> [any AXNode] {
    guard let found = value(attribute) as? [AXUIElement] else { return [] }
    return found.map { SystemAXNode(element: $0) }
  }

  func markedSelection() -> String? {
    guard let range = value("AXSelectedTextMarkerRange") else { return nil }
    var text: CFTypeRef?
    let status = AXUIElementCopyParameterizedAttributeValue(
      element, "AXStringForTextMarkerRange" as CFString, range, &text)
    guard status == .success else { return nil }
    return text as? String
  }

  private func value(_ attribute: String) -> AnyObject? {
    var found: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &found) == .success else {
      return nil
    }
    return found
  }
}

import ApplicationServices
import ThoughtsCore

struct SelectionInspector {
  static let nodeLimit = 400
  static let ancestorLimit = 32
  static let copyKey = "c"

  var expired: () -> Bool = { false }

  func probe(
    focused: (any AXNode)?, menuBar: () -> (any AXNode)?
  ) -> SelectionProbe {
    if let focused {
      if isSecure(focused) { return .secureField }
      switch reading(of: focused) {
      case .text(let text): return .text(text)
      case .empty: return .empty
      case .unknown: break
      }
    }
    return copyIsDisabled(menuBar()) ? .copyDisabled : .unavailable
  }

  private enum Reading {
    case text(String)
    case empty
    case unknown
  }

  private func reading(of element: any AXNode) -> Reading {
    var answered = false
    if let plain = element.string(kAXSelectedTextAttribute) {
      if !plain.isEmpty { return .text(plain) }
      answered = true
    }
    if let marked = element.markedSelection() {
      if !marked.isEmpty { return .text(marked) }
      answered = true
    }
    return answered && isNativeTextControl(element) ? .empty : .unknown
  }

  private func isNativeTextControl(_ element: any AXNode) -> Bool {
    switch element.string(kAXRoleAttribute) {
    case "AXTextField", "AXComboBox": return true
    case "AXTextArea": return !hasWebAreaAncestor(element)
    default: return false
    }
  }

  private func hasWebAreaAncestor(_ element: any AXNode) -> Bool {
    var current = element
    for _ in 0..<Self.ancestorLimit {
      if expired() { return true }
      guard let parent = current.node(kAXParentAttribute) else { return false }
      if parent.string(kAXRoleAttribute) == "AXWebArea" { return true }
      current = parent
    }
    return true
  }

  private func isSecure(_ element: any AXNode) -> Bool {
    [kAXRoleAttribute, kAXSubroleAttribute].contains { element.string($0) == "AXSecureTextField" }
  }

  private func copyIsDisabled(_ menuBar: (any AXNode)?) -> Bool {
    guard let menuBar else { return false }
    var visited = 0
    for barItem in menuBar.nodes(kAXChildrenAttribute).dropFirst() {
      for menu in barItem.nodes(kAXChildrenAttribute) {
        for item in menu.nodes(kAXChildrenAttribute) {
          visited += 1
          if visited > Self.nodeLimit || expired() { return false }
          if isCopy(item) { return item.flag(kAXEnabledAttribute) == false }
        }
      }
    }
    return false
  }

  private func isCopy(_ item: any AXNode) -> Bool {
    item.string(kAXMenuItemCmdCharAttribute)?.lowercased() == Self.copyKey
      && item.integer(kAXMenuItemCmdModifiersAttribute) == 0
  }
}

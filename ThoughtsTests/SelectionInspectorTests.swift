import ApplicationServices
import Testing
import ThoughtsCore

@testable import Thoughts

struct SelectionInspectorTests {
  final class Node: AXNode {
    var strings: [String: String] = [:]
    var integers: [String: Int] = [:]
    var flags: [String: Bool] = [:]
    var links: [String: Node] = [:]
    var lists: [String: [Node]] = [:]
    var marked: String?

    init(role: String? = nil, selected: String? = nil, marked: String? = nil) {
      strings[kAXRoleAttribute] = role
      strings[kAXSelectedTextAttribute] = selected
      self.marked = marked
    }

    func string(_ attribute: String) -> String? { strings[attribute] }
    func integer(_ attribute: String) -> Int? { integers[attribute] }
    func flag(_ attribute: String) -> Bool? { flags[attribute] }
    func node(_ attribute: String) -> (any AXNode)? { links[attribute] }
    func nodes(_ attribute: String) -> [any AXNode] { lists[attribute] ?? [] }
    func markedSelection() -> String? { marked }
  }

  static func item(
    key: String?, modifiers: Int = 0, enabled: Bool? = true, title: String = "Copy"
  ) -> Node {
    let item = Node()
    item.strings[kAXTitleAttribute] = title
    item.strings[kAXMenuItemCmdCharAttribute] = key
    item.integers[kAXMenuItemCmdModifiersAttribute] = modifiers
    item.flags[kAXEnabledAttribute] = enabled
    return item
  }

  static func menuBar(menus: [[Node]]) -> Node {
    let bar = Node()
    let titles = ["Apple"] + (1...max(menus.count, 1)).map { "Menu \($0)" }
    let barItems = zip(titles, [[]] + menus).map { title, items -> Node in
      let barItem = Node()
      barItem.strings[kAXTitleAttribute] = title
      let menu = Node()
      menu.lists[kAXChildrenAttribute] = items
      barItem.lists[kAXChildrenAttribute] = [menu]
      return barItem
    }
    bar.lists[kAXChildrenAttribute] = barItems
    return bar
  }

  static func edit(copy: Node) -> Node {
    menuBar(menus: [
      [item(key: "N", title: "New")],
      [item(key: "Z", title: "Undo"), item(key: "X", title: "Cut"), copy],
    ])
  }

  static func probe(
    focused: Node?, menuBar: Node?, expired: @escaping () -> Bool = { false }
  ) -> SelectionProbe {
    SelectionInspector(expired: expired).probe(focused: focused, menuBar: { menuBar })
  }

  @Test func aSelectionIsReadWithoutTouchingTheMenuBar() {
    var menuRead = false
    let result = SelectionInspector().probe(
      focused: Node(role: "AXWebArea", selected: "chosen words"),
      menuBar: {
        menuRead = true
        return nil
      })
    #expect(result == .text("chosen words"))
    #expect(!menuRead)
  }

  @Test func aMarkedRangeSelectionIsRead() {
    let result = Self.probe(focused: Node(role: "AXWebArea", marked: "from safari"), menuBar: nil)
    #expect(result == .text("from safari"))
  }

  @Test func aTextFieldThatReportsAnEmptySelectionNeedsNoCopy() {
    let field = Node(role: "AXTextField", selected: "")
    let bar = Self.edit(copy: Self.item(key: "c", enabled: true))
    #expect(Self.probe(focused: field, menuBar: bar) == .empty)
  }

  @Test func anEmptyMarkedRangeNeedsNoCopy() {
    let area = Node(role: "AXWebArea", marked: "")
    #expect(Self.probe(focused: area, menuBar: nil) == .empty)
  }

  @Test func anEmptyAnswerFromAnOtherElementFallsToTheCopyItem() {
    let page = Node(role: "AXWebArea", selected: "")
    let disabled = Self.edit(copy: Self.item(key: "c", enabled: false))
    let enabled = Self.edit(copy: Self.item(key: "c", enabled: true))
    #expect(Self.probe(focused: page, menuBar: disabled) == .copyDisabled)
    #expect(Self.probe(focused: page, menuBar: enabled) == .unavailable)
  }

  @Test func noFocusedElementFallsToTheCopyItem() {
    let disabled = Self.edit(copy: Self.item(key: "c", enabled: false))
    let enabled = Self.edit(copy: Self.item(key: "c", enabled: true))
    #expect(Self.probe(focused: nil, menuBar: disabled) == .copyDisabled)
    #expect(Self.probe(focused: nil, menuBar: enabled) == .unavailable)
  }

  @Test func appsThatGiveNoEvidenceKeepTheCopyFallback() {
    let silent = Node(role: "AXGroup")
    let unreadable = Self.edit(copy: Self.item(key: "c", enabled: nil))
    let noCopy = Self.menuBar(menus: [[Self.item(key: "N", title: "New")]])
    #expect(Self.probe(focused: silent, menuBar: nil) == .unavailable)
    #expect(Self.probe(focused: silent, menuBar: unreadable) == .unavailable)
    #expect(Self.probe(focused: silent, menuBar: noCopy) == .unavailable)
    #expect(Self.probe(focused: nil, menuBar: Node()) == .unavailable)
  }

  @Test func theCopyItemIsFoundByItsKeyEquivalentInAnyLanguage() {
    let localized = Self.edit(copy: Self.item(key: "C", enabled: false, title: "Copiar"))
    #expect(Self.probe(focused: nil, menuBar: localized) == .copyDisabled)
  }

  @Test func onlyCommandCIsTheCopyItem() {
    let shifted = Self.menuBar(menus: [
      [Self.item(key: "C", modifiers: 1, enabled: false, title: "Copy Style")]
    ])
    #expect(Self.probe(focused: nil, menuBar: shifted) == .unavailable)
  }

  @Test func theAppleMenuIsNotSearched() {
    let bar = Node()
    let apple = Node()
    let menu = Node()
    menu.lists[kAXChildrenAttribute] = [Self.item(key: "C", enabled: false)]
    apple.lists[kAXChildrenAttribute] = [menu]
    bar.lists[kAXChildrenAttribute] = [apple]
    #expect(Self.probe(focused: nil, menuBar: bar) == .unavailable)
  }

  @Test func aPasswordFieldNeverReadsOrCopies() {
    let secure = Node(role: "AXSecureTextField", selected: "hunter2")
    let bar = Self.edit(copy: Self.item(key: "c", enabled: false))
    #expect(Self.probe(focused: secure, menuBar: bar) == .secureField)
  }

  @Test func theMenuSearchStopsWhenTheBudgetIsSpent() {
    let disabled = Self.edit(copy: Self.item(key: "c", enabled: false))
    #expect(Self.probe(focused: nil, menuBar: disabled, expired: { true }) == .unavailable)
  }

  @Test func theMenuSearchStopsAtTheNodeLimit() {
    let filler = (0..<SelectionInspector.nodeLimit).map { _ in Self.item(key: "Q", title: "Quit") }
    let bar = Self.menuBar(menus: [filler + [Self.item(key: "c", enabled: false)]])
    #expect(Self.probe(focused: nil, menuBar: bar) == .unavailable)
  }
}

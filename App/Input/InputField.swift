import AppKit
import SwiftUI

class FocusableTextField: NSTextField {
  var onFocus: (() -> Void)?
  var onTextChange: ((String) -> Void)?
  var takesLines: Bool { false }
  private var wantsFocus = false

  func setFocused(_ focused: Bool) {
    let changed = focused != wantsFocus
    wantsFocus = focused
    guard focused || changed else { return }
    applyFocus()
    scheduleFocus()
  }

  private func scheduleFocus() {
    for delay in [0.0, 0.05, 0.2] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.applyFocus() }
    }
  }

  private func applyFocus() {
    guard let window else { return }
    if wantsFocus {
      if currentEditor() == nil {
        window.makeFirstResponder(self)
        currentEditor()?.selectedRange = NSRange(location: stringValue.utf16.count, length: 0)
      }
    } else if currentEditor() != nil {
      window.makeFirstResponder(nil)
    }
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard wantsFocus, window != nil else { return }
    scheduleFocus()
  }

  override func becomeFirstResponder() -> Bool {
    let accepted = super.becomeFirstResponder()
    guard accepted, !wantsFocus else { return accepted }
    if isPersonsMove(NSApp.currentEvent) {
      onFocus?()
    } else {
      DispatchQueue.main.async { [weak self] in self?.giveFocusBack() }
    }
    return accepted
  }

  private func isPersonsMove(_ event: NSEvent?) -> Bool {
    guard let event, event.window === window else { return false }
    switch event.type {
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
      return bounds.contains(convert(event.locationInWindow, from: nil))
    case .keyDown:
      return event.keyCode == 48
    default:
      return false
    }
  }

  private func giveFocusBack() {
    guard let window, !wantsFocus, currentEditor() != nil else { return }
    window.makeFirstResponder(nil)
    guard let content = window.contentView else { return }
    for field in Self.wantedFields(in: content) { field.applyFocus() }
  }

  private static func wantedFields(in view: NSView) -> [FocusableTextField] {
    if let field = view as? FocusableTextField { return field.wantsFocus ? [field] : [] }
    return view.subviews.flatMap(wantedFields(in:))
  }
}

final class InputTextField: FocusableTextField {
  override var takesLines: Bool { true }
}

struct InputField: NSViewRepresentable {
  @Binding var text: String
  let isFocused: Bool
  let onFocus: () -> Void

  static let font = NSFont.systemFont(ofSize: 13)
  static let maxLines = 5
  static let lineHeight = height(of: " ", width: .greatestFiniteMagnitude)

  static func height(of text: String, width: CGFloat) -> CGFloat {
    let measured = text.isEmpty || text.hasSuffix("\n") ? text + " " : text
    let cell = NSTextFieldCell(textCell: measured)
    cell.font = font
    cell.wraps = true
    cell.lineBreakMode = .byWordWrapping
    let bounds = NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)
    return cell.cellSize(forBounds: bounds).height
  }

  static func fieldHeight(of text: String, width: CGFloat) -> CGFloat {
    min(height(of: text, width: width), lineHeight * CGFloat(maxLines))
  }

  func makeNSView(context: Context) -> InputTextField {
    let field = InputTextField()
    field.isBordered = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.font = Self.font
    field.textColor = .labelColor
    field.placeholderAttributedString = NSAttributedString(
      string: String(localized: "Add a thought"),
      attributes: [.font: Self.font, .foregroundColor: NSColor.tertiaryLabelColor])
    field.usesSingleLineMode = false
    field.cell?.wraps = true
    field.cell?.isScrollable = false
    field.lineBreakMode = .byWordWrapping
    field.setAccessibilityLabel(String(localized: "Add a thought"))
    field.stringValue = text
    return field
  }

  func updateNSView(_ field: InputTextField, context: Context) {
    field.onFocus = onFocus
    field.onTextChange = { [text = $text] in
      if text.wrappedValue != $0 { text.wrappedValue = $0 }
    }
    let current = field.currentEditor()?.string ?? field.stringValue
    if current != text { field.stringValue = text }
    field.setFocused(isFocused)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: InputTextField, context: Context)
    -> CGSize?
  {
    let width = proposal.width ?? 200
    return CGSize(width: width, height: Self.fieldHeight(of: text, width: width))
  }
}

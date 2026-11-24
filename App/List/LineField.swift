import AppKit
import SwiftUI

struct LineField: NSViewRepresentable {
  @Binding var text: String
  let placeholder: String
  let isFocused: Bool
  let onFocus: () -> Void
  let make: () -> FocusableTextField

  func makeNSView(context: Context) -> FocusableTextField {
    let field = make()
    field.isBordered = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.font = .systemFont(ofSize: 13)
    field.textColor = .labelColor
    field.placeholderAttributedString = NSAttributedString(
      string: placeholder,
      attributes: [
        .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.tertiaryLabelColor,
      ])
    field.usesSingleLineMode = true
    field.cell?.isScrollable = true
    field.lineBreakMode = .byClipping
    field.setAccessibilityLabel(placeholder)
    field.stringValue = text
    return field
  }

  func updateNSView(_ field: FocusableTextField, context: Context) {
    field.onFocus = onFocus
    field.onTextChange = { [text = $text] in
      if text.wrappedValue != $0 { text.wrappedValue = $0 }
    }
    field.setText(text)
    field.setFocused(isFocused)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: FocusableTextField, context: Context)
    -> CGSize?
  {
    CGSize(width: proposal.width ?? 200, height: nsView.intrinsicContentSize.height)
  }
}

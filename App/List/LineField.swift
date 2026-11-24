import AppKit
import SwiftUI

struct LineField: NSViewRepresentable {
  @Binding var text: String
  let placeholder: String
  let isFocused: Bool
  let onFocus: () -> Void
  let make: () -> FocusableTextField

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

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
    field.delegate = context.coordinator
    field.setAccessibilityLabel(placeholder)
    field.stringValue = text
    return field
  }

  func updateNSView(_ field: FocusableTextField, context: Context) {
    context.coordinator.text = $text
    field.onFocus = onFocus
    let current = field.currentEditor()?.string ?? field.stringValue
    if current != text { field.stringValue = text }
    field.setFocused(isFocused)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: FocusableTextField, context: Context)
    -> CGSize?
  {
    CGSize(width: proposal.width ?? 200, height: nsView.intrinsicContentSize.height)
  }

  final class Coordinator: NSObject, NSTextFieldDelegate {
    var text: Binding<String>

    init(text: Binding<String>) {
      self.text = text
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSTextField else { return }
      text.wrappedValue = field.stringValue
    }
  }
}

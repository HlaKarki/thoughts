import AppKit
import SwiftUI

final class InputTextField: NSTextField {
  var onFocus: (() -> Void)?
  private var wantsFocus = false

  func setFocused(_ focused: Bool) {
    let changed = focused != wantsFocus
    wantsFocus = focused
    guard focused || changed else { return }
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
    if accepted { onFocus?() }
    return accepted
  }
}

struct InputField: NSViewRepresentable {
  @Binding var text: String
  let isFocused: Bool
  let onFocus: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  func makeNSView(context: Context) -> InputTextField {
    let field = InputTextField()
    field.isBordered = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.font = .systemFont(ofSize: 13)
    field.textColor = .labelColor
    field.placeholderAttributedString = NSAttributedString(
      string: String(localized: "Add a thought"),
      attributes: [
        .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.tertiaryLabelColor,
      ])
    field.usesSingleLineMode = true
    field.cell?.isScrollable = true
    field.lineBreakMode = .byClipping
    field.delegate = context.coordinator
    field.setAccessibilityLabel(String(localized: "Add a thought"))
    field.stringValue = text
    return field
  }

  func updateNSView(_ field: InputTextField, context: Context) {
    context.coordinator.text = $text
    field.onFocus = onFocus
    let current = field.currentEditor()?.string ?? field.stringValue
    if current != text { field.stringValue = text }
    field.setFocused(isFocused)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: InputTextField, context: Context)
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

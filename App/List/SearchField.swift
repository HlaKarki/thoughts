import AppKit
import SwiftUI

final class SearchTextField: FocusableTextField {}

private struct SearchTextInput: NSViewRepresentable {
  @Binding var text: String
  let isFocused: Bool
  let onFocus: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  func makeNSView(context: Context) -> SearchTextField {
    let field = SearchTextField()
    field.isBordered = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.font = .systemFont(ofSize: 13)
    field.textColor = .labelColor
    field.placeholderAttributedString = NSAttributedString(
      string: String(localized: "Search thoughts"),
      attributes: [
        .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.tertiaryLabelColor,
      ])
    field.usesSingleLineMode = true
    field.cell?.isScrollable = true
    field.lineBreakMode = .byClipping
    field.delegate = context.coordinator
    field.setAccessibilityLabel(String(localized: "Search thoughts"))
    field.stringValue = text
    return field
  }

  func updateNSView(_ field: SearchTextField, context: Context) {
    context.coordinator.text = $text
    field.onFocus = onFocus
    let current = field.currentEditor()?.string ?? field.stringValue
    if current != text { field.stringValue = text }
    field.setFocused(isFocused)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: SearchTextField, context: Context)
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

struct SearchField: View {
  @Bindable var list: ListModel

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color(nsColor: .systemGray))
      SearchTextInput(
        text: $list.query, isFocused: list.focus == .search, onFocus: { list.focus = .search }
      )
      if !list.query.isEmpty {
        Button {
          list.query = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .systemGray))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear search")
      }
    }
    .padding(.horizontal, 10)
    .frame(height: 32)
    .background(Color.primary.opacity(0.06), in: FieldShape(cornerRadius: 9))
  }
}

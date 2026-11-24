import AppKit
import SwiftUI

final class SearchTextField: FocusableTextField {}

struct SearchField: View {
  @Bindable var list: ListModel

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color(nsColor: .systemGray))
      LineField(
        text: $list.query, placeholder: String(localized: "Search thoughts"),
        isFocused: list.focus == .search, onFocus: { list.fieldDidTakeFocus(.search) },
        make: { SearchTextField() })
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

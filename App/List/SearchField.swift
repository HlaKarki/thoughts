import SwiftUI

struct SearchField: View {
  @Bindable var list: ListModel
  var field: FocusState<Focus?>.Binding

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color(nsColor: .systemGray))
      TextField(
        "", text: $list.query,
        prompt: Text("Search thoughts").foregroundStyle(Color(nsColor: .tertiaryLabelColor))
      )
      .textFieldStyle(.plain)
      .font(.system(size: 13))
      .focusEffectDisabled()
      .focused(field, equals: .search)
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

import SwiftUI

struct ActionBar: View {
  let focus: Focus
  let hasEntries: Bool
  let inputIsEmpty: Bool
  let hasAttachment: Bool

  var body: some View {
    HStack(spacing: 14) {
      ForEach(hints, id: \.key) { hint in
        KeyHint(label: hint.label, key: hint.key)
      }
    }
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, minHeight: 16, alignment: .trailing)
  }

  private var hints: [Hint] {
    switch focus {
    case .list:
      return [
        Hint(label: "Copy", key: "⌘C"),
        Hint(label: "Edit", key: "↵"),
        Hint(label: "Done", key: "⌘↵"),
        Hint(label: "Actions", key: "⌘K"),
      ]
    case .search:
      return [Hint(label: "Select", key: "↓"), Hint(label: "Clear", key: "esc")]
    case .input:
      if hasAttachment {
        return [Hint(label: "Add", key: "↵"), Hint(label: "Remove image", key: "esc")]
      }
      var hints: [Hint] = []
      if inputIsEmpty {
        if hasEntries { hints.append(Hint(label: "Select", key: "↑")) }
        hints.append(Hint(label: "Paste", key: "⌘V"))
      } else {
        hints.append(Hint(label: "Add", key: "↵"))
      }
      if hasEntries { hints.append(Hint(label: "Search", key: "⌘F")) }
      hints.append(Hint(label: "Hide", key: "esc"))
      return hints
    }
  }

  private struct Hint {
    let label: LocalizedStringKey
    let key: String
  }
}

struct KeyHint: View {
  let label: LocalizedStringKey
  let key: String

  var body: some View {
    HStack(spacing: 5) {
      Text(label)
      Text(verbatim: key)
        .padding(.horizontal, 4)
        .frame(minWidth: 16, minHeight: 16)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
    }
    .font(.system(size: 11))
    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
    .frame(height: 16)
  }
}

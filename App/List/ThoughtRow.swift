import SwiftUI
import ThoughtsCore

struct RowFrame<Content: View>: View {
  let time: String
  let selected: Bool
  @ViewBuilder let content: Content
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      content
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(verbatim: time)
        .font(.system(size: 11))
        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: 40, minHeight: 18, alignment: .trailing)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 6)
    .background {
      if selected {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
      }
    }
    .contentShape(Rectangle())
  }
}

struct ThoughtRow: View {
  let thought: Thought
  let time: String
  let selected: Bool

  private static let doneOpacity = 0.45
  private static let doneTextOpacity = 0.7

  var body: some View {
    RowFrame(time: time, selected: selected) {
      switch thought.content {
      case .text(let text):
        label(of: text)
      case .image(let fileName, let note):
        VStack(alignment: .leading, spacing: 6) {
          RowThumbnail(
            url: thought.file.deletingLastPathComponent().appendingPathComponent(fileName)
          )
          .opacity(isDone ? Self.doneOpacity : 1)
          if !note.isEmpty { label(of: note) }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: accessibilityLabel))
  }

  private var isDone: Bool { thought.done != nil }

  private func label(of text: String) -> some View {
    Text(verbatim: text)
      .font(.system(size: 13))
      .lineSpacing(2)
      .padding(.vertical, 1)
      .lineLimit(4)
      .truncationMode(.tail)
      .strikethrough(isDone)
      .foregroundStyle(
        isDone
          ? Color(nsColor: .secondaryLabelColor).opacity(Self.doneTextOpacity)
          : Color(nsColor: .labelColor)
      )
      .fixedSize(horizontal: false, vertical: true)
  }

  private var accessibilityLabel: String {
    var parts: [String]
    switch thought.content {
    case .text(let text):
      parts = [text]
    case .image(_, let note):
      parts = [String(localized: "Screenshot")]
      if !note.isEmpty { parts.append(note) }
    }
    parts.append(time)
    if isDone { parts.append(String(localized: "done")) }
    return parts.joined(separator: ", ")
  }
}

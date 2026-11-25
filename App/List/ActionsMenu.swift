import SwiftUI

final class MenuTextField: FocusableTextField {}

struct ActionsMenu: View {
  @Bindable var list: ListModel

  static let width: CGFloat = 252
  static let rowHeight: CGFloat = 30
  static let space = "thoughts.actions"

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let items = list.menuItems
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        if items.isEmpty {
          Text("No actions")
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
        }
        ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
          if item.destructive, offset > 0 {
            Rectangle()
              .fill(Color(nsColor: .separatorColor))
              .frame(height: 1)
          }
          row(item, highlighted: offset == list.menuHighlight, offset: offset)
            .onGeometryChange(for: CGRect.self) {
              $0.frame(in: .named(Self.space))
            } action: {
              list.placeMenuRow(item.id, at: $0)
            }
            .onDisappear { list.placeMenuRow(item.id, at: nil) }
        }
      }
      .padding(6)
      .overlay {
        PointerTracker { list.menuPointerMoved(to: $0) }
          .allowsHitTesting(false)
      }
      .coordinateSpace(.named(Self.space))
      Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 1)
      LineField(
        text: $list.menuQuery, placeholder: String(localized: "Search actions"),
        isFocused: list.focus == .menu, onFocus: { list.fieldDidTakeFocus(.menu) },
        make: { MenuTextField() }
      )
      .padding(.horizontal, 14)
      .frame(height: 36)
    }
    .frame(width: Self.width)
    .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    .shadow(color: .black.opacity(0.16), radius: 15, y: 10)
  }

  private var fill: Color {
    colorScheme == .dark ? Color(white: 0.172) : Color.white
  }

  private func row(_ item: ActionItem, highlighted: Bool, offset: Int) -> some View {
    Button {
      list.menuHighlight = offset
      list.perform(.menuRun)
    } label: {
      HStack(spacing: 8) {
        Text(verbatim: item.title)
          .font(.system(size: 13))
          .foregroundStyle(Color(nsColor: .labelColor))
          .lineLimit(1)
        Spacer(minLength: 8)
        Text(verbatim: item.shortcut)
          .font(.system(size: 11))
          .foregroundStyle(Color(nsColor: .secondaryLabelColor))
          .padding(.horizontal, 4)
          .frame(minWidth: 16, minHeight: 16)
          .background(
            highlighted ? Color.primary.opacity(0.1) : Color.primary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 4))
      }
      .padding(.horizontal, 8)
      .frame(height: Self.rowHeight)
      .background {
        if highlighted {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.primary.opacity(0.08))
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(verbatim: item.title))
    .accessibilityAddTraits(highlighted ? .isSelected : [])
  }
}

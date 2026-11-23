import SwiftUI

struct PanelRootView: View {
  let preferences: Preferences
  @Environment(\.colorScheme) private var colorScheme
  @State private var query = ""
  @State private var draft = ""

  var body: some View {
    VStack(spacing: 0) {
      header
      emptyState
      composer
    }
    .frame(width: PanelController.width)
    .frame(maxHeight: .infinity)
    .background { PanelBackground() }
    .clipShape(RoundedRectangle(cornerRadius: PanelBackground.cornerRadius, style: .continuous))
  }

  private var header: some View {
    HStack(spacing: 8) {
      HStack(spacing: 7) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Color(nsColor: .systemGray))
        TextField(
          "", text: $query,
          prompt: Text("Search thoughts").foregroundStyle(Color(nsColor: .tertiaryLabelColor))
        )
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .focusEffectDisabled()
      }
      .padding(.horizontal, 10)
      .frame(height: 32)
      .background(Color.primary.opacity(0.06), in: FieldShape(cornerRadius: 9))
      MoreMenu(preferences: preferences)
    }
    .padding(.top, 12)
    .padding(.bottom, 10)
    .padding(.horizontal, 12)
  }

  private var inputFill: Color {
    colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.7)
  }

  private var emptyState: some View {
    VStack(spacing: 6) {
      Text("No thoughts yet")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.primary)
      Text(
        "Type below and press Return to add one. In any app, press ⇧⇧ to save the selected text or a copied image."
      )
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .lineSpacing(3)
    }
    .padding(.horizontal, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var composer: some View {
    VStack(spacing: 8) {
      TextField(
        "", text: $draft,
        prompt: Text("Add a thought").foregroundStyle(Color(nsColor: .tertiaryLabelColor))
      )
      .textFieldStyle(.plain)
      .font(.system(size: 13))
      .focusEffectDisabled()
      .padding(.horizontal, 10)
      .frame(height: 38)
      .background(inputFill, in: FieldShape(cornerRadius: 10))
      .overlay {
        FieldShape(cornerRadius: 10)
          .strokeBorder(Color.primary.opacity(0.13), lineWidth: 1)
      }
      HStack(spacing: 14) {
        KeyHint(label: "Paste", key: "⌘V")
        KeyHint(label: "Hide", key: "esc")
      }
      .padding(.horizontal, 4)
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(.top, 10)
    .padding(.bottom, 12)
    .padding(.horizontal, 12)
    .overlay(alignment: .top) {
      Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 1)
    }
  }
}

private struct KeyHint: View {
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
    .foregroundStyle(.secondary)
    .frame(height: 16)
  }
}

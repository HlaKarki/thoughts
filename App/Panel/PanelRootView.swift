import SwiftUI

struct PanelRootView: View {
  let preferences: Preferences
  @Bindable var list: ListModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var draft = ""
  @FocusState private var field: Focus?

  var body: some View {
    VStack(spacing: 0) {
      header
      listArea
      composer
    }
    .frame(width: PanelController.width)
    .frame(maxHeight: .infinity)
    .background { PanelBackground() }
    .clipShape(RoundedRectangle(cornerRadius: PanelBackground.cornerRadius, style: .continuous))
    .background {
      KeyRoutingView { stroke in
        guard
          let command = KeyRouter.command(
            for: stroke, focus: list.focus, inputIsEmpty: draft.isEmpty, hasAttachment: false)
        else { return false }
        list.perform(command)
        return true
      }
    }
    .onChange(of: list.focus) { _, focus in
      field = focus == .list ? nil : focus
    }
    .onChange(of: field) { _, focus in
      if let focus, list.focus != focus { list.focus = focus }
    }
    .onAppear { field = list.focus == .list ? nil : list.focus }
  }

  private var header: some View {
    HStack(spacing: 8) {
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
        .focused($field, equals: .search)
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
      MoreMenu(preferences: preferences, onClearDone: { list.clearDone() })
    }
    .padding(.top, 12)
    .padding(.bottom, 10)
    .padding(.horizontal, 12)
  }

  @ViewBuilder
  private var listArea: some View {
    Group {
      if !list.visible.isEmpty {
        ThoughtListView(model: list)
      } else if list.isSearching {
        NoMatchesView()
      } else {
        EmptyListView()
      }
    }
    .overlay(alignment: .bottom) { HintLine(text: list.hint) }
  }

  private var inputFill: Color {
    colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.7)
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
      .focused($field, equals: .input)
      .padding(.horizontal, 10)
      .frame(height: 38)
      .background(inputFill, in: FieldShape(cornerRadius: 10))
      .overlay {
        FieldShape(cornerRadius: 10)
          .strokeBorder(Color.primary.opacity(0.13), lineWidth: 1)
      }
      ActionBar(
        focus: list.focus,
        hasEntries: !list.visible.isEmpty,
        inputIsEmpty: draft.isEmpty,
        hasAttachment: false)
    }
    .padding(.top, 10)
    .padding(.bottom, 12)
    .padding(.horizontal, 12)
    .overlay(alignment: .top) {
      Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 1)
    }
  }
}

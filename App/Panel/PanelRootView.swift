import SwiftUI

struct PanelRootView: View {
  let preferences: Preferences
  @Bindable var list: ListModel
  @Bindable var input: InputModel
  var shared = SharedMenuItems(updates: UpdateMenuItem(), openSettings: nil, checkForUpdates: nil)
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
    .overlay { menuLayer }
    .clipShape(RoundedRectangle(cornerRadius: PanelBackground.cornerRadius, style: .continuous))
    .background {
      KeyRoutingView { stroke in
        guard
          let command = KeyRouter.command(
            for: stroke, focus: list.focus, inputIsEmpty: input.text.isEmpty,
            hasAttachment: input.attachment != nil)
        else { return false }
        list.perform(command)
        return true
      }
    }
    .onChange(of: list.focus) { _, focus in
      field = Self.fieldTarget(for: focus)
    }
    .onChange(of: field) { _, focus in
      if let focus, list.focus != focus { list.focus = focus }
    }
    .animation(.easeOut(duration: PanelController.duration), value: list.isMenuOpen)
    .animation(.easeOut(duration: PanelController.duration), value: input.attachment != nil)
    .animation(.easeOut(duration: PanelController.duration), value: input.isDropTargeted)
    .onAppear { field = Self.fieldTarget(for: list.focus) }
  }

  @ViewBuilder
  private var menuLayer: some View {
    if list.isMenuOpen {
      ZStack(alignment: .bottomTrailing) {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { list.closeMenu() }
        ActionsMenu(list: list, field: $field)
          .padding(.trailing, 12)
          .padding(.bottom, Self.menuBottomInset)
      }
      .transition(.opacity)
    }
  }

  static let menuBottomInset: CGFloat = 74

  private static func fieldTarget(for focus: Focus) -> Focus? {
    focus == .menu ? focus : nil
  }

  private var header: some View {
    HStack(spacing: 8) {
      SearchField(list: list)
      MoreMenu(preferences: preferences, shared: shared, onClearDone: { list.clearDone() })
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
        EmptyListView(preferences: preferences)
      }
    }
    .overlay {
      ListScrim()
        .opacity(input.attachment != nil && list.focus == .input ? 1 : 0)
        .animation(.easeOut(duration: PanelController.duration), value: list.focus == .input)
    }
    .overlay(alignment: .bottom) {
      if case .image(_, let preview) = input.attachment {
        AttachmentPreview(image: preview, onRemove: { input.removeAttachment() })
          .padding(.horizontal, 12)
          .padding(.bottom, AttachmentPreview.verticalInset)
          .transition(.opacity)
      }
    }
    .overlay {
      if input.isDropTargeted { DropTargetView().transition(.opacity) }
    }
  }

  private var composer: some View {
    InputView(list: list, input: input)
  }
}

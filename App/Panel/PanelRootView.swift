import SwiftUI

struct PanelRootView: View {
  let preferences: Preferences
  @Bindable var list: ListModel
  @Bindable var input: InputModel
  var shared = SharedMenuItems(updates: UpdateMenuItem(), openSettings: nil, checkForUpdates: nil)
  @State private var inputBoxHeight = InputView.boxHeight

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
            for: stroke, focus: list.focus, menuIsOpen: list.isMenuOpen,
            inputIsEmpty: input.text.isEmpty, hasAttachment: input.attachment != nil)
        else { return false }
        list.perform(command)
        return true
      }
    }
    .animation(.easeOut(duration: PanelController.duration), value: list.isMenuOpen)
    .animation(.easeOut(duration: PanelController.duration), value: input.attachment != nil)
    .animation(.easeOut(duration: PanelController.duration), value: input.isDropTargeted)
  }

  @ViewBuilder
  private var menuLayer: some View {
    if list.isMenuOpen {
      ZStack(alignment: .bottomTrailing) {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { list.closeMenu() }
        ActionsMenu(list: list)
          .padding(.trailing, 12)
          .padding(.bottom, Self.menuBottomInset + inputBoxHeight - InputView.boxHeight)
      }
      .transition(.opacity)
    }
  }

  static let menuBottomInset: CGFloat = 74

  private var header: some View {
    HStack(spacing: 8) {
      SearchField(list: list)
      MoreMenu(preferences: preferences, shared: shared, onClearDone: { list.perform(.clearDone) })
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
          .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(RowHover.space))
          } action: {
            list.hover.cover($0)
          }
          .onDisappear { list.hover.cover(nil) }
          .padding(.horizontal, 12)
          .padding(.bottom, AttachmentPreview.verticalInset)
          .transition(.opacity)
      }
    }
    .overlay {
      if input.isDropTargeted { DropTargetView().transition(.opacity) }
    }
    .overlay {
      PointerTracker { list.hover.pointerMoved(to: $0) }
        .allowsHitTesting(false)
    }
    .coordinateSpace(.named(RowHover.space))
  }

  private var composer: some View {
    InputView(list: list, input: input, boxHeight: $inputBoxHeight)
  }
}

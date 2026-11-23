import SwiftUI

struct PanelRootView: View {
  let preferences: Preferences
  @Bindable var list: ListModel
  @Bindable var input: InputModel
  var onOpenSettings: (() -> Void)?
  var updates: UpdateMenuItem?
  var onCheckForUpdates: (() -> Void)?
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
    .onChange(of: list.searchCaretRequests) {
      for delay in [0.0, 0.05, 0.2] {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          Self.placeCaretAtEnd(of: list.query)
        }
      }
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

  private static func placeCaretAtEnd(of text: String) {
    for case let panel as ThoughtsPanel in NSApp.windows {
      guard let editor = panel.firstResponder as? NSTextView, editor.string == text,
        editor.selectedRange().length > 0
      else { continue }
      editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
    }
  }

  private static func fieldTarget(for focus: Focus) -> Focus? {
    focus == .search || focus == .menu ? focus : nil
  }

  private var header: some View {
    HStack(spacing: 8) {
      SearchField(list: list, field: $field)
      MoreMenu(
        preferences: preferences, onClearDone: { list.clearDone() }, onOpenSettings: onOpenSettings,
        onCheckForUpdates: onCheckForUpdates, updateAvailable: updates?.isShown ?? false)
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
      HintLine(text: list.shownHint)
        .padding(.bottom, previewInset)
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

  private var previewInset: CGFloat {
    guard case .image(_, let preview) = input.attachment else { return 0 }
    return AttachmentPreview.height(for: preview, width: PanelController.width - 24)
      + AttachmentPreview.verticalInset
  }

  private var composer: some View {
    InputView(list: list, input: input)
  }
}

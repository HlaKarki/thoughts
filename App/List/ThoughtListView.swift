import SwiftUI
import ThoughtsCore

struct ThoughtListView: View {
  let model: ListModel

  var body: some View {
    GeometryReader { proxy in
      ScrollViewReader { scroller in
        ScrollView {
          LazyVStack(spacing: 4) {
            ForEach(model.visible, id: \.fileName) { entry in
              row(for: entry)
            }
          }
          .padding(.top, 4)
          .padding(.bottom, 8)
          .padding(.horizontal, 12)
          .frame(minHeight: proxy.size.height, alignment: .bottom)
        }
        .defaultScrollAnchor(.bottom)
        .onChange(of: model.addedCount) {
          guard let last = model.visible.last else { return }
          scroller.scrollTo(last.fileName, anchor: .bottom)
        }
        .onChange(of: model.selection.last) {
          guard let name = model.selection.last else { return }
          scroller.scrollTo(name, anchor: nil)
        }
      }
    }
  }

  @ViewBuilder
  private func row(for entry: ThoughtEntry) -> some View {
    let name = entry.fileName
    let selected = model.selection.contains(name)
    let time = timeLabel(for: entry)
    let editing = model.editing?.name == name
    Group {
      switch entry {
      case .thought(let thought) where editing:
        EditRow(thought: thought, time: time, list: model)
      case .thought(let thought):
        ThoughtRow(
          thought: thought, time: time, selected: selected,
          terms: model.isSearching ? model.searchTerms : nil,
          imageExcerpt: model.imageExcerpts[thought.id.rawValue]
        )
        .onDrag { DragOut.provider(for: thought) }
      case .malformed(let file, let reason):
        WarningRow(fileName: file.lastPathComponent, reason: reason, time: time, selected: selected)
      }
    }
    .id(name)
    .onTapGesture(count: 2) {
      guard !editing else { return }
      model.select(name, extend: false)
      model.perform(.edit)
    }
    .simultaneousGesture(
      TapGesture().onEnded {
        guard !editing else { return }
        model.select(name, extend: NSEvent.modifierFlags.contains(.shift))
      }
    )
    .overlay {
      if !editing {
        RightClickCatcher {
          if !model.selection.contains(name) { model.select(name, extend: false) }
          model.focus = .list
          model.perform(.actionsMenu)
        }
      }
    }
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func timeLabel(for entry: ThoughtEntry) -> String {
    guard let date = model.date(of: entry) else { return "" }
    return RowTime.label(for: date, now: model.now, calendar: .current, locale: .current)
  }
}

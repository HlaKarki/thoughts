import AppKit
import SwiftUI
import ThoughtsCore

final class EditTextView: NSTextView {
  static let font = NSFont.systemFont(ofSize: 13)
  static let lineSpacing: CGFloat = 2

  init() {
    let storage = NSTextStorage()
    let layout = NSLayoutManager()
    let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    storage.addLayoutManager(layout)
    layout.addTextContainer(container)
    super.init(frame: .zero, textContainer: container)
    container.lineFragmentPadding = 0
    container.widthTracksTextView = true
    textContainerInset = .zero
    isHorizontallyResizable = false
    isVerticallyResizable = false
    drawsBackground = false
    isRichText = false
    allowsUndo = true
    isAutomaticQuoteSubstitutionEnabled = false
    isAutomaticDashSubstitutionEnabled = false
    isAutomaticTextReplacementEnabled = false
    isAutomaticSpellingCorrectionEnabled = false
    font = Self.font
    textColor = .labelColor
    let style = NSMutableParagraphStyle()
    style.lineSpacing = Self.lineSpacing
    defaultParagraphStyle = style
    typingAttributes = [
      .font: Self.font, .foregroundColor: NSColor.labelColor, .paragraphStyle: style,
    ]
    setAccessibilityLabel(String(localized: "Edit thought"))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  func setText(_ text: String) {
    guard string != text else { return }
    textStorage?.setAttributedString(
      NSAttributedString(string: text, attributes: typingAttributes))
  }

  func height(fitting width: CGFloat) -> CGFloat {
    guard let layout = layoutManager, let container = textContainer else { return 18 }
    container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
    layout.ensureLayout(for: container)
    let used = layout.usedRect(for: container).height
    let extra = layout.extraLineFragmentRect.maxY
    return max(ceil(max(used, extra)), 18)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard window != nil else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self, let window = self.window else { return }
      window.makeFirstResponder(self)
      setSelectedRange(NSRange(location: (string as NSString).length, length: 0))
    }
  }

  override func keyDown(with event: NSEvent) {
    let isReturn = event.keyCode == 36 || event.keyCode == 76
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    if isReturn, flags.contains(.shift), !flags.contains(.command) {
      insertText("\n", replacementRange: selectedRange())
      return
    }
    super.keyDown(with: event)
  }
}

struct EditField: NSViewRepresentable {
  @Binding var text: String

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  func makeNSView(context: Context) -> EditTextView {
    let view = EditTextView()
    view.delegate = context.coordinator
    view.setText(text)
    return view
  }

  func updateNSView(_ view: EditTextView, context: Context) {
    context.coordinator.text = $text
    view.setText(text)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: EditTextView, context: Context)
    -> CGSize?
  {
    let width = proposal.width ?? 200
    return CGSize(width: width, height: nsView.height(fitting: width))
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var text: Binding<String>

    init(text: Binding<String>) {
      self.text = text
    }

    func textDidChange(_ notification: Notification) {
      guard let view = notification.object as? NSTextView else { return }
      text.wrappedValue = view.string
    }
  }
}

struct EditRow: View {
  let thought: Thought
  let time: String
  @Bindable var list: ListModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    RowFrame(time: time, selected: false) {
      VStack(alignment: .leading, spacing: 6) {
        if let url = thought.imageFileURL { RowThumbnail(url: url) }
        EditField(text: $list.editText)
          .padding(.vertical, 1)
      }
    }
    .background { surface }
  }

  private var surface: some View {
    let accent = Color(nsColor: .controlAccentColor)
    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
    return
      shape
      .fill(colorScheme == .dark ? Color(white: 0.165) : Color.white)
      .background { shape.stroke(accent.opacity(0.2), lineWidth: 8) }
      .overlay { shape.strokeBorder(accent, lineWidth: 1) }
  }
}

import AppKit

final class PasteFieldEditor: NSTextView {
  var pasteboard: NSPasteboard = .general
  var onPaste: ((NSPasteboard) -> Bool)?

  override func paste(_ sender: Any?) {
    if onPaste?(pasteboard) == true { return }
    super.paste(sender)
  }

  override func registerForDraggedTypes(_ newTypes: [NSPasteboard.PasteboardType]) {}

  override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
    if item.action == #selector(NSText.paste(_:)), canPaste { return true }
    return super.validateUserInterfaceItem(item)
  }

  private var canPaste: Bool {
    if case .nothing = PasteboardReader.paste(from: pasteboard) { return false }
    return true
  }
}

final class ThoughtsPanel: NSPanel {
  var onCancel: (() -> Void)?
  var pasteboard: NSPasteboard = .general
  var onPaste: ((NSPasteboard) -> Bool)?
  private var pasteEditor: PasteFieldEditor?

  init(content: NSView) {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: true)
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    hidesOnDeactivate = false
    isMovable = false
    isReleasedWhenClosed = false
    animationBehavior = .none
    contentView = content
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func cancelOperation(_ sender: Any?) {
    onCancel?()
  }

  static func editAction(for event: NSEvent) -> Selector? {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard let key = event.charactersIgnoringModifiers?.lowercased() else { return nil }
    switch (key, flags) {
    case ("x", .command): return Selector(("cut:"))
    case ("c", .command): return Selector(("copy:"))
    case ("v", .command): return Selector(("paste:"))
    case ("a", .command): return Selector(("selectAll:"))
    case ("z", .command): return Selector(("undo:"))
    case ("z", [.command, .shift]): return Selector(("redo:"))
    default: return nil
    }
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if let action = Self.editAction(for: event), send(action) { return true }
    return super.performKeyEquivalent(with: event)
  }

  private func send(_ action: Selector) -> Bool {
    var responder = firstResponder
    while let current = responder {
      if current.tryToPerform(action, with: nil) { return true }
      responder = current.nextResponder
    }
    return false
  }

  override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
    let accepted = super.makeFirstResponder(responder)
    if accepted, let editor = firstResponder as? NSTextView { editor.unregisterDraggedTypes() }
    return accepted
  }

  override func fieldEditor(_ createFlag: Bool, for object: Any?) -> NSText? {
    guard object is InputTextField else {
      return super.fieldEditor(createFlag, for: object)
    }
    if let pasteEditor { return configured(pasteEditor) }
    guard createFlag else { return nil }
    let editor = PasteFieldEditor()
    editor.isFieldEditor = true
    editor.allowsUndo = true
    pasteEditor = editor
    return configured(editor)
  }

  private func configured(_ editor: PasteFieldEditor) -> PasteFieldEditor {
    editor.pasteboard = pasteboard
    editor.onPaste = onPaste
    return editor
  }
}

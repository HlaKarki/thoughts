import AppKit

final class PasteFieldEditor: NSTextView {
  var pasteboard: NSPasteboard = .general
  var onPaste: ((NSPasteboard) -> Bool)?

  func followTextChanges() {
    NotificationCenter.default.addObserver(
      self, selector: #selector(storageDidProcessEditing(_:)),
      name: NSTextStorage.didProcessEditingNotification, object: textStorage)
  }

  override func resignFirstResponder() -> Bool {
    let resigned = super.resignFirstResponder()
    if resigned, let textStorage { undoManager?.removeAllActions(withTarget: textStorage) }
    return resigned
  }

  @objc private func storageDidProcessEditing(_ notification: Notification) {
    guard textStorage?.editedMask.contains(.editedCharacters) == true,
      let field = delegate as? FocusableTextField, field.currentEditor() === self
    else { return }
    field.onTextChange?(string)
  }

  override func insertNewline(_ sender: Any?) {
    guard (delegate as? FocusableTextField)?.takesLines == true else { return }
    insertNewlineIgnoringFieldEditor(sender)
  }

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
    pasteboard.availableType(from: [.fileURL, .string, .png, .tiff]) != nil
  }
}

enum StandardKey: Equatable {
  case openSettings
  case belongsToFrontApp
}

final class ThoughtsPanel: NSPanel {
  var onCancel: (() -> Void)?
  var onOpenSettings: (() -> Void)?
  var pasteboard: NSPasteboard = .general
  var onPaste: ((NSPasteboard) -> Bool)?
  var onNothingToDo: ((HistoryDirection) -> Void)?
  var defersHistory: ((HistoryDirection) -> Bool)?
  let sharedUndoManager = UndoManager()
  private var pasteEditor: PasteFieldEditor?

  override var undoManager: UndoManager? { sharedUndoManager }

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
      .subtracting([.capsLock, .numericPad, .function])
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

  static func standardKey(for event: NSEvent) -> StandardKey? {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      .subtracting([.capsLock, .numericPad, .function])
    guard flags.contains(.command), !flags.contains(.control),
      let key = event.charactersIgnoringModifiers?.lowercased()
    else { return nil }
    if key == ",", flags == .command { return .openSettings }
    return ["q", "h", "m", "w"].contains(key) ? .belongsToFrontApp : nil
  }

  static func historyDirection(for event: NSEvent) -> HistoryDirection? {
    switch editAction(for: event) {
    case Selector(("undo:")): .undo
    case Selector(("redo:")): .redo
    default: nil
    }
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    switch Self.standardKey(for: event) {
    case .openSettings:
      onOpenSettings?()
      return true
    case .belongsToFrontApp:
      return true
    case nil:
      break
    }
    if let direction = Self.historyDirection(for: event) { return step(direction) }
    if let action = Self.editAction(for: event), send(action) { return true }
    return super.performKeyEquivalent(with: event)
  }

  private func step(_ direction: HistoryDirection) -> Bool {
    if defersHistory?(direction) == true { return true }
    let manager = sharedUndoManager
    let typing = firstResponder is NSTextView && manager.groupingLevel > 0
    let available = direction == .undo ? manager.canUndo : manager.canRedo
    guard available || typing else {
      onNothingToDo?(direction)
      return true
    }
    if direction == .undo { manager.undo() } else { manager.redo() }
    return true
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
    guard object is FocusableTextField else {
      return super.fieldEditor(createFlag, for: object)
    }
    if let pasteEditor { return configured(pasteEditor) }
    guard createFlag else { return nil }
    let editor = PasteFieldEditor()
    editor.isFieldEditor = true
    editor.allowsUndo = true
    editor.followTextChanges()
    pasteEditor = editor
    return configured(editor)
  }

  private func configured(_ editor: PasteFieldEditor) -> PasteFieldEditor {
    editor.pasteboard = pasteboard
    editor.onPaste = onPaste
    return editor
  }
}

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

struct PanelDrag {
  let pointer: CGPoint
  let origin: CGPoint
  var moved = false
}

final class ThoughtsPanel: NSPanel {
  static let dragThreshold: CGFloat = 3

  var onCancel: (() -> Void)?
  var onDragStart: (() -> Bool)?
  var onDragEnd: (() -> Void)?
  private(set) var findingGrabArea = false
  private var drag: PanelDrag?
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

  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDown:
      grabPanel(atWindow: event.locationInWindow, pointer: NSEvent.mouseLocation)
    case .leftMouseDragged:
      if dragPanel(to: NSEvent.mouseLocation) { return }
    case .leftMouseUp:
      super.sendEvent(event)
      endDrag()
      return
    default:
      break
    }
    super.sendEvent(event)
  }

  func isGrabArea(atWindow point: CGPoint) -> Bool {
    guard let content = contentView else { return false }
    findingGrabArea = true
    defer { findingGrabArea = false }
    return content.hitTest(content.superview?.convert(point, from: nil) ?? point) is PanelGrabView
  }

  @discardableResult
  func grabPanel(atWindow point: CGPoint, pointer: CGPoint) -> Bool {
    drag = nil
    guard isGrabArea(atWindow: point), onDragStart?() == true else { return false }
    drag = PanelDrag(pointer: pointer, origin: frame.origin)
    return true
  }

  func dragPanel(to pointer: CGPoint) -> Bool {
    guard var drag else { return false }
    let dx = pointer.x - drag.pointer.x
    let dy = pointer.y - drag.pointer.y
    if !drag.moved {
      guard hypot(dx, dy) >= Self.dragThreshold else { return false }
      drag.moved = true
      self.drag = drag
      setFrameAtOnce(frame)
    }
    setFrameOrigin(CGPoint(x: drag.origin.x + dx, y: drag.origin.y + dy))
    return true
  }

  func endDrag() {
    guard let drag else { return }
    self.drag = nil
    if drag.moved { onDragEnd?() }
  }

  func cancelDrag() -> Bool {
    defer { drag = nil }
    return drag?.moved == true
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
    guard let key = event.charactersIgnoringModifiers else { return nil }
    return standardKey(key, flags)
  }

  static func standardKey(_ key: String, _ flags: NSEvent.ModifierFlags) -> StandardKey? {
    guard flags.contains(.command), !flags.contains(.control) else { return nil }
    let key = key.lowercased()
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

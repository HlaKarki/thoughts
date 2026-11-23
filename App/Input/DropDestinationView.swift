import AppKit

final class DropDestinationView: NSView {
  var onEnter: () -> Void = {}
  var onExit: () -> Void = {}
  var onDrop: (NSPasteboard) -> Bool = { _ in false }

  init(content: NSView? = nil) {
    super.init(frame: .zero)
    if let content {
      content.frame = bounds
      content.autoresizingMask = [.width, .height]
      addSubview(content)
    }
    registerForDraggedTypes([.fileURL, .png, .tiff, .string])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
    guard sender.draggingSource == nil else { return [] }
    onEnter()
    return .copy
  }

  override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
    sender.draggingSource == nil ? .copy : []
  }

  override func draggingExited(_ sender: (any NSDraggingInfo)?) {
    onExit()
  }

  override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    sender.draggingSource == nil
  }

  override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
    onExit()
    return onDrop(sender.draggingPasteboard)
  }
}

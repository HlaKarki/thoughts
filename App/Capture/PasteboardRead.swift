import AppKit

struct PasteboardRead: @unchecked Sendable {
  let pasteboard: NSPasteboard

  func run<T: Sendable>(_ read: @escaping @Sendable (NSPasteboard) -> T) async -> T {
    await Task.detached { [self] in read(pasteboard) }.value
  }
}

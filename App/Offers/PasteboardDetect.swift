import AppKit
import Synchronization
import UniformTypeIdentifiers

enum PasteboardDetect {
  static let timeout: TimeInterval = 2

  private final class Once: Sendable {
    private let continuation: Mutex<CheckedContinuation<UTType?, Never>?>

    init(_ continuation: CheckedContinuation<UTType?, Never>) {
      self.continuation = Mutex(continuation)
    }

    func resume(_ value: UTType?) {
      let taken = continuation.withLock { held -> CheckedContinuation<UTType?, Never>? in
        defer { held = nil }
        return held
      }
      taken?.resume(returning: value)
    }
  }

  @MainActor
  static func contentType(of pasteboard: NSPasteboard) async -> UTType? {
    await withCheckedContinuation { continuation in
      let once = Once(continuation)
      pasteboard.__detectMetadata(forTypes: [__NSPasteboardMetadataType.__contentType]) {
        @Sendable metadata, _ in
        once.resume(metadata?[__NSPasteboardMetadataType.__contentType] as? UTType)
      }
      DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { once.resume(nil) }
    }
  }
}

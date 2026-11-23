import AppKit
import KeyboardShortcuts
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
  let name: KeyboardShortcuts.Name
  var onChange: ((KeyboardShortcuts.Shortcut?) -> Void)?

  init(for name: KeyboardShortcuts.Name, onChange: ((KeyboardShortcuts.Shortcut?) -> Void)? = nil) {
    self.name = name
    self.onChange = onChange
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
    let recorder = KeyboardShortcuts.RecorderCocoa(for: name) { shortcut in
      context.coordinator.onChange?(shortcut)
    }
    context.coordinator.watch(recorder)
    return recorder
  }

  func updateNSView(_ recorder: KeyboardShortcuts.RecorderCocoa, context: Context) {
    context.coordinator.onChange = onChange
    recorder.shortcutName = name
  }

  @MainActor
  final class Coordinator {
    var onChange: ((KeyboardShortcuts.Shortcut?) -> Void)?
    private var observer: NSObjectProtocol?
    private weak var recorder: KeyboardShortcuts.RecorderCocoa?

    func watch(_ recorder: KeyboardShortcuts.RecorderCocoa) {
      self.recorder = recorder
      observer = NotificationCenter.default.addObserver(
        forName: NSWindow.didUpdateNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.settleEditor() }
      }
    }

    private func settleEditor() {
      guard let recorder, let editor = recorder.currentEditor() as? NSTextView,
        let clip = editor.superview, clip !== recorder
      else { return }
      recorder.layoutSubtreeIfNeeded()
      let fitted = CGRect(origin: .zero, size: clip.bounds.size)
      if editor.frame != fitted { editor.frame = fitted }
      if editor.selectedRange().length > 0 {
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
      }
    }

    isolated deinit {
      if let observer { NotificationCenter.default.removeObserver(observer) }
    }
  }
}

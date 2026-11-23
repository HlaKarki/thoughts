import AppKit
import ThoughtsCore

enum DragOut {
  static func provider(for thought: Thought) -> NSItemProvider? {
    switch thought.content {
    case .text(let text):
      return NSItemProvider(object: text as NSString)
    case .image:
      guard let url = thought.imageFileURL,
        let provider = NSItemProvider(contentsOf: url)
      else { return nil }
      return provider
    }
  }
}

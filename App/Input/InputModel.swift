import AppKit
import Observation
import ThoughtsCore
import UniformTypeIdentifiers

enum Attachment: Equatable {
  case image(ImageInput, preview: NSImage)

  static func == (lhs: Attachment, rhs: Attachment) -> Bool {
    switch (lhs, rhs) {
    case (.image(let left, let leftPreview), .image(let right, let rightPreview)):
      leftPreview === rightPreview && Self.same(left, right)
    }
  }

  private static func same(_ lhs: ImageInput, _ rhs: ImageInput) -> Bool {
    switch (lhs, rhs) {
    case (.data(let left, let leftType), .data(let right, let rightType)):
      left == right && leftType == rightType
    case (.file(let left), .file(let right)):
      left == right
    default:
      false
    }
  }
}

struct ManualSave: Equatable {
  let file: URL
  let pasteboardChangeCount: Int?
}

@MainActor
@Observable
final class InputModel {
  var text = ""
  var attachment: Attachment?
  var isDropTargeted = false

  @ObservationIgnored var onManualSave: (ManualSave) -> Void = { _ in }
  @ObservationIgnored var source: @MainActor () async -> Source? = { nil }
  @ObservationIgnored private let location: StorageLocation
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let onFailure: (String) -> Void
  @ObservationIgnored private var attachmentChangeCount: Int?

  init(
    location: StorageLocation,
    now: @escaping () -> Date = Date.init,
    onFailure: @escaping (String) -> Void
  ) {
    self.location = location
    self.now = now
    self.onFailure = onFailure
  }

  func submit() async {
    let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let content: NewContent
    if case .image(let input, _) = attachment {
      content = .image(input, note: note)
    } else {
      guard !note.isEmpty else { return }
      content = .text(note)
    }
    let held = (text: text, attachment: attachment, changeCount: attachmentChangeCount)
    text = ""
    attachment = nil
    attachmentChangeCount = nil
    let recorded = await source()
    let added = await add(
      NewThought(content: content, source: recorded, created: now()),
      pasteboardChangeCount: held.changeCount)
    if !added, text.isEmpty, attachment == nil {
      text = held.text
      attachment = held.attachment
      attachmentChangeCount = held.changeCount
    }
  }

  func paste(_ pasteboard: NSPasteboard) {
    if takeImage(from: pasteboard) { return }
    if let string = pasteboard.string(forType: .string) { text += string }
  }

  @discardableResult
  func takeImage(from pasteboard: NSPasteboard) -> Bool {
    guard case .image(let input, let preview) = PasteboardReader.paste(from: pasteboard) else {
      return false
    }
    attachment = .image(input, preview: preview)
    attachmentChangeCount = pasteboard.changeCount
    return true
  }

  func removeAttachment() {
    attachment = nil
    attachmentChangeCount = nil
  }

  func drop(_ pasteboard: NSPasteboard, source: Source? = nil) -> Bool {
    let dropped = DropReader.thoughts(from: pasteboard, source: source, now: now())
    guard !dropped.isEmpty else { return false }
    let needsSource = source == nil
    Task {
      let recorded = needsSource ? await self.source() : nil
      await add(dropped.map { Self.applying(recorded, to: $0) })
    }
    return true
  }

  private static func applying(_ source: Source?, to thought: NewThought) -> NewThought {
    guard var merged = source else { return thought }
    merged.file = thought.source?.file
    var result = thought
    result.source = merged
    return result
  }

  func add(_ thoughts: [NewThought]) async {
    for thought in thoughts { await add(thought, pasteboardChangeCount: nil) }
  }

  @discardableResult
  private func add(_ new: NewThought, pasteboardChangeCount: Int?) async -> Bool {
    do {
      let store = ThoughtStore(folder: try location.resolve())
      let saved = try await Task.detached { try store.add(new) }.value
      onManualSave(ManualSave(file: saved.file, pasteboardChangeCount: pasteboardChangeCount))
      return true
    } catch let error as ThoughtsError {
      onFailure(ListModel.message(for: error))
    } catch {
      onFailure(error.localizedDescription)
    }
    return false
  }
}

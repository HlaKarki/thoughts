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
  let sourceFile: URL?
  let pasteboardChangeCount: Int?
}

@MainActor
@Observable
final class InputModel {
  var text = ""
  var attachment: Attachment? {
    didSet { composerVersion += 1 }
  }
  var isDropTargeted = false

  @ObservationIgnored var onManualSave: (ManualSave) -> Void = { _ in }
  @ObservationIgnored var source: @MainActor () async -> Source? = { nil }
  @ObservationIgnored private let location: StorageLocation
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let onFailure: (String) -> Void
  @ObservationIgnored private var attachmentChangeCount: Int?
  @ObservationIgnored private var ledger = SavedLedger()
  @ObservationIgnored private(set) var pasteRead: Task<Void, Never>?
  @ObservationIgnored private var composerVersion = 0
  @ObservationIgnored private let files = BlockingQueue("thoughts.input.files", concurrent: true)

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
      guard !note.isEmpty else {
        onFailure(String(localized: "Type a thought first"))
        return
      }
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
    switch PasteboardReader.paste(from: pasteboard) {
    case .image(let input, let preview):
      attachment = .image(input, preview: preview)
      attachmentChangeCount = pasteboard.changeCount
      return true
    case .imageFiles(let found):
      read(found, from: pasteboard)
      return true
    case .text, .nothing:
      return false
    }
  }

  private func read(_ found: [URL], from pasteboard: NSPasteboard) {
    composerVersion += 1
    let version = composerVersion
    let changeCount = pasteboard.changeCount
    let files = files
    pasteRead = Task { [weak self] in
      let read = await files.run { PasteboardReader.preview(of: found) }
      guard let self, self.composerVersion == version, pasteboard.changeCount == changeCount
      else { return }
      guard let read else {
        self.onFailure(String(localized: "That image file can't be read"))
        return
      }
      self.attachment = .image(.file(read.file), preview: read.preview)
      self.attachmentChangeCount = changeCount
    }
  }

  func removeAttachment() {
    attachment = nil
    attachmentChangeCount = nil
  }

  func drop(_ pasteboard: NSPasteboard, source: Source? = nil) -> Bool {
    let dropped = DropReader.thoughts(from: pasteboard, source: source, now: now())
    guard !dropped.isEmpty else {
      onFailure(String(localized: "Drop text, an image or a file"))
      return false
    }
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

  func savedLedger() -> SavedLedger {
    ledger.pruned { FileManager.default.fileExists(atPath: $0.path) }
  }

  func thought(at file: URL) -> Thought? {
    let store = ThoughtStore(folder: file.deletingLastPathComponent())
    guard case .thought(let thought)? = try? store.entry(at: file) else { return nil }
    return thought
  }

  @discardableResult
  func save(_ new: NewThought, pasteboardChangeCount: Int?) async throws -> Thought {
    let store = ThoughtStore(folder: try location.resolve())
    let saved = try await Task.detached { try store.add(new) }.value
    var text: String?
    if case .text(let value) = new.content { text = value }
    ledger.record(
      SavedEntry(
        file: saved.file, clipboardCounts: pasteboardChangeCount.map { [$0] } ?? [], text: text,
        source: new.source ?? Source()))
    let sourceFile = new.source?.file.map { URL(fileURLWithPath: $0) }
    onManualSave(
      ManualSave(
        file: saved.file, sourceFile: sourceFile, pasteboardChangeCount: pasteboardChangeCount))
    return saved
  }

  @discardableResult
  private func add(_ new: NewThought, pasteboardChangeCount: Int?) async -> Bool {
    do {
      try await save(new, pasteboardChangeCount: pasteboardChangeCount)
      return true
    } catch let error as ThoughtsError {
      onFailure(ListModel.message(for: error))
    } catch {
      onFailure(error.localizedDescription)
    }
    return false
  }
}

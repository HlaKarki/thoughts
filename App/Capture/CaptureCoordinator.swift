import AppKit
import ThoughtsCore
import UniformTypeIdentifiers

enum CaptureOutcome: Equatable {
  case saved(Thought)
  case acceptedOffer(Thought)
  case alreadySaved(Thought?)
  case nothingToSave
  case failed(String)
}

@MainActor
final class CaptureCoordinator {
  private let frontmost: @MainActor () -> AppSnapshot?
  private let ownBundleID: String
  private let ownWindowIsKey: @MainActor () -> Bool
  private let reader: any SelectionReading
  private let source: @MainActor () async -> Source
  private let input: InputModel
  private let pasteboard: NSPasteboard
  private let writer: PasteboardWriter
  private let sound: SavedSound
  private let now: () -> Date
  private let currentOffer: (() -> OfferID?)?
  private let acceptOffer: (() async throws -> Thought)?
  private let clipboardCopy: (() -> ClipboardCopy?)?
  private let pollClipboard: (@MainActor () async -> Int)?
  private let accessBehavior: @MainActor () -> NSPasteboard.AccessBehavior
  private let log: @MainActor (CaptureTrail) -> Void
  private(set) var isCapturing = false

  init(
    frontmost: @escaping @MainActor () -> AppSnapshot?,
    ownBundleID: String,
    ownWindowIsKey: @escaping @MainActor () -> Bool,
    reader: any SelectionReading,
    source: @escaping @MainActor () async -> Source,
    input: InputModel,
    writer: PasteboardWriter,
    sound: SavedSound,
    pasteboard: NSPasteboard = .general,
    now: @escaping () -> Date = Date.init,
    currentOffer: (() -> OfferID?)? = nil,
    acceptOffer: (() async throws -> Thought)? = nil,
    clipboardCopy: (() -> ClipboardCopy?)? = nil,
    pollClipboard: (@MainActor () async -> Int)? = nil,
    accessBehavior: (@MainActor () -> NSPasteboard.AccessBehavior)? = nil,
    log: @escaping @MainActor (CaptureTrail) -> Void = CaptureLog.record
  ) {
    self.frontmost = frontmost
    self.ownBundleID = ownBundleID
    self.ownWindowIsKey = ownWindowIsKey
    self.reader = reader
    self.source = source
    self.input = input
    self.writer = writer
    self.sound = sound
    self.pasteboard = pasteboard
    self.now = now
    self.currentOffer = currentOffer
    self.acceptOffer = acceptOffer
    self.clipboardCopy = clipboardCopy
    self.pollClipboard = pollClipboard
    self.accessBehavior = accessBehavior ?? { [pasteboard] in pasteboard.accessBehavior }
    self.log = log
  }

  func capture() async -> CaptureOutcome {
    guard !isCapturing else { return .nothingToSave }
    isCapturing = true
    defer { isCapturing = false }
    async let recorded = source()
    let polledCount = await pollClipboard?()
    let app = frontmost()
    let offer = currentOffer?()
    let ownWindow = ownWindowIsKey()
    let secureInput = reader.secureInputOn
    var trail = CaptureTrail(
      secureInput: secureInput, polledCount: polledCount, currentCount: pasteboard.changeCount,
      now: now())
    trail.probe = offer == nil && !ownWindow ? await probe(app) : nil
    let selection = trail.probe ?? .empty
    let recordedSource = await recorded
    let fallbackAllowed =
      !ownWindow && !secureInput
      && CopyFallbackPolicy.allowed(bundleID: app?.bundleID, ownBundleID: ownBundleID)
    var current = context(
      offer: offer, selection: selection, fallbackAllowed: fallbackAllowed,
      source: recordedSource)
    var action = CaptureDecision.decide(current)
    if action == .copyFallback {
      trail.fallbackRan = true
      (current, action) = await decideAfterCopy(source: recordedSource)
    }
    var held: ImageInput?
    if action == .readClipboard {
      let read = await readClipboard(expecting: current.changeCount)
      current.clipboardContent = read.content
      held = read.image
      action = CaptureDecision.decide(current)
    }
    trail.copy = current.clipboard
    trail.action = action
    trail.now = current.now
    log(trail)
    switch action {
    case .acceptOffer:
      return await accept()
    case .saveText(let text):
      return await save(
        .text(text.trimmingCharacters(in: .whitespacesAndNewlines)), recordedSource)
    case .saveCopiedText(let text, let source):
      return await save(
        .text(text.trimmingCharacters(in: .whitespacesAndNewlines)), source,
        pasteboardChangeCount: current.changeCount)
    case .saveClipboardImage:
      return await saveClipboardImage(held, recordedSource, expecting: current.changeCount)
    case .alreadySaved(let file):
      return .alreadySaved(input.thought(at: file))
    case .clipboardRefused:
      return .failed(Self.pasteRefusedMessage)
    case .copyFallback, .readClipboard, .nothingToSave:
      return .nothingToSave
    }
  }

  private func probe(_ app: AppSnapshot?) async -> SelectionProbe {
    guard let app else { return .unavailable }
    if app.bundleID == ownBundleID { return .empty }
    return await reader.probe(pid: app.pid)
  }

  private func context(
    offer: OfferID?, selection: SelectionProbe, fallbackAllowed: Bool, source: Source,
    copy: ClipboardCopy? = nil, equivalentCounts: [Int] = []
  ) -> CaptureContext {
    CaptureContext(
      offer: offer, selection: selection, fallbackAllowed: fallbackAllowed,
      clipboard: copy ?? clipboardCopy?(), changeCount: pasteboard.changeCount,
      equivalentCounts: equivalentCounts, saved: input.savedLedger(), source: source, now: now())
  }

  private func decideAfterCopy(source: Source) async -> (CaptureContext, CaptureAction) {
    let countBefore = pasteboard.changeCount
    let before = clipboardCopy?().flatMap { $0.changeCount == countBefore ? $0 : nil }
    let (copied, counts) = await reader.copySelection()
    for count in counts { writer.noteOwn(count) }
    let copy = before?.moved(to: pasteboard.changeCount)
    let after = context(
      offer: nil, selection: copied, fallbackAllowed: false, source: source, copy: copy,
      equivalentCounts: before == nil ? [] : [countBefore])
    return (after, CaptureDecision.decide(after))
  }

  private func readClipboard(expecting changeCount: Int) async -> (
    content: ClipboardContent, image: ImageInput?
  ) {
    let read = await PasteboardRead(pasteboard: pasteboard).run(expecting: changeCount) {
      board -> (content: ClipboardContent, image: ImageInput?)? in
      if let image = Self.image(in: board) { return (.image, image) }
      if !PasteboardReader.fileURLs(in: board).isEmpty { return (.nothing, nil) }
      return board.string(forType: .string).map { (.text($0), nil) }
    }
    guard case .read(let found) = read else { return (.nothing, nil) }
    return found ?? (accessBehavior() == .alwaysAllow ? .nothing : .refused, nil)
  }

  private func accept() async -> CaptureOutcome {
    guard let acceptOffer else { return .nothingToSave }
    do {
      let thought = try await acceptOffer()
      return .acceptedOffer(thought)
    } catch {
      return .failed(Self.message(for: error))
    }
  }

  private func saveClipboardImage(
    _ held: ImageInput?, _ recorded: Source, expecting changeCount: Int
  ) async -> CaptureOutcome {
    guard pasteboard.changeCount == changeCount else {
      return .failed(Self.message(for: ThoughtsError.clipboardChanged))
    }
    var found = held
    if held == nil {
      let read = await PasteboardRead(pasteboard: pasteboard).run(expecting: changeCount) {
        Self.image(in: $0)
      }
      guard case .read(let image) = read else { return .nothingToSave }
      found = image
    }
    guard let image = found else {
      return accessBehavior() == .alwaysAllow ? .nothingToSave : .failed(Self.pasteRefusedMessage)
    }
    var source = recorded
    if case .file(let file) = image { source.file = file.path }
    return await save(.image(image, note: ""), source, pasteboardChangeCount: changeCount)
  }

  private func save(
    _ content: NewContent, _ recorded: Source, pasteboardChangeCount: Int? = nil
  ) async -> CaptureOutcome {
    let new = NewThought(
      content: content, source: recorded == Source() ? nil : recorded, created: now())
    do {
      let thought = try await input.save(new, pasteboardChangeCount: pasteboardChangeCount)
      sound.play()
      return .saved(thought)
    } catch {
      return .failed(Self.message(for: error))
    }
  }

  nonisolated static func image(in pasteboard: NSPasteboard) -> ImageInput? {
    let files = PasteboardReader.fileURLs(in: pasteboard)
    if !files.isEmpty {
      return files.first {
        UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true
      }.map { .file($0) }
    }
    return PasteboardReader.imageData(in: pasteboard).map { .data($0.data, $0.type) }
  }

  static var pasteRefusedMessage: String {
    String(localized: "macOS didn't let Thoughts paste from other apps")
  }

  static func message(for error: Error) -> String {
    if let error = error as? ThoughtsError { return ListModel.message(for: error) }
    return error.localizedDescription
  }
}

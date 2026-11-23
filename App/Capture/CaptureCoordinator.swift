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
  private let clipboardImage: (() -> ClipboardImage?)?
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
    clipboardImage: (() -> ClipboardImage?)? = nil
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
    self.clipboardImage = clipboardImage
  }

  func capture() async -> CaptureOutcome {
    guard !isCapturing else { return .nothingToSave }
    isCapturing = true
    defer { isCapturing = false }
    async let recorded = source()
    let app = frontmost()
    let offer = currentOffer?()
    let ownWindow = ownWindowIsKey()
    let selection = offer == nil && !ownWindow ? await probe(app) : .empty
    let recordedSource = await recorded
    let fallbackAllowed =
      !ownWindow
      && CopyFallbackPolicy.allowed(bundleID: app?.bundleID, ownBundleID: ownBundleID)
    var action = CaptureDecision.decide(
      context(
        offer: offer, selection: selection, fallbackAllowed: fallbackAllowed,
        source: recordedSource))
    if action == .copyFallback {
      action = await decideAfterCopy(source: recordedSource)
    }
    switch action {
    case .acceptOffer:
      return await accept()
    case .saveText(let text):
      return await save(
        .text(text.trimmingCharacters(in: .whitespacesAndNewlines)), recordedSource)
    case .saveClipboardImage:
      let imageCount = pasteboard.changeCount
      return await saveClipboardImage(recordedSource, expecting: imageCount)
    case .alreadySaved(let file):
      return .alreadySaved(input.thought(at: file))
    case .copyFallback, .nothingToSave:
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
    image: ClipboardImage? = nil, equivalentCounts: [Int] = []
  ) -> CaptureContext {
    CaptureContext(
      offer: offer, selection: selection, fallbackAllowed: fallbackAllowed,
      clipboardImage: image ?? clipboardImage?(), changeCount: pasteboard.changeCount,
      equivalentCounts: equivalentCounts, saved: input.savedLedger(), source: source, now: now())
  }

  private func decideAfterCopy(source: Source) async -> CaptureAction {
    let countBefore = pasteboard.changeCount
    let before = clipboardImage?().flatMap { $0.changeCount == countBefore ? $0 : nil }
    let (copied, counts) = await reader.copySelection()
    for count in counts { writer.noteOwn(count) }
    let image = before.map { ClipboardImage(changeCount: pasteboard.changeCount, seen: $0.seen) }
    return CaptureDecision.decide(
      context(
        offer: nil, selection: copied, fallbackAllowed: false, source: source, image: image,
        equivalentCounts: before == nil ? [] : [countBefore]))
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

  private func saveClipboardImage(_ recorded: Source, expecting changeCount: Int) async
    -> CaptureOutcome
  {
    guard pasteboard.changeCount == changeCount else {
      return .failed(Self.message(for: ThoughtsError.clipboardChanged))
    }
    guard let image = Self.image(in: pasteboard) else { return .nothingToSave }
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

  static func image(in pasteboard: NSPasteboard) -> ImageInput? {
    let files = PasteboardReader.fileURLs(in: pasteboard)
    if !files.isEmpty {
      return files.first {
        UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true
      }.map { .file($0) }
    }
    return PasteboardReader.imageData(in: pasteboard).map { .data($0.data, $0.type) }
  }

  static func message(for error: Error) -> String {
    if let error = error as? ThoughtsError { return ListModel.message(for: error) }
    return error.localizedDescription
  }
}

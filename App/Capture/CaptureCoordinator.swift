import AppKit
import ThoughtsCore
import UniformTypeIdentifiers

enum CaptureOutcome: Equatable {
  case saved(Thought)
  case acceptedOffer(Thought)
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
    let fallbackAllowed =
      !ownWindow
      && CopyFallbackPolicy.allowed(bundleID: app?.bundleID, ownBundleID: ownBundleID)
    var action = CaptureDecision.decide(
      context(offer: offer, selection: selection, fallbackAllowed: fallbackAllowed))
    if action == .copyFallback {
      action = await decideAfterCopy()
    }
    switch action {
    case .acceptOffer:
      return await accept()
    case .saveText(let text):
      let recordedSource = await recorded
      return await save(
        .text(text.trimmingCharacters(in: .whitespacesAndNewlines)), recordedSource)
    case .saveClipboardImage:
      let imageCount = pasteboard.changeCount
      let recordedSource = await recorded
      return await saveClipboardImage(recordedSource, expecting: imageCount)
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
    offer: OfferID?, selection: SelectionProbe, fallbackAllowed: Bool,
    image: ClipboardImage? = nil
  ) -> CaptureContext {
    CaptureContext(
      offer: offer, selection: selection, fallbackAllowed: fallbackAllowed,
      clipboardImage: image ?? clipboardImage?(), changeCount: pasteboard.changeCount, now: now())
  }

  private func decideAfterCopy() async -> CaptureAction {
    let before = clipboardImage?().flatMap { $0.changeCount == pasteboard.changeCount ? $0 : nil }
    let (copied, counts) = await reader.copySelection()
    for count in counts { writer.noteOwn(count) }
    let image = before.map { ClipboardImage(changeCount: pasteboard.changeCount, seen: $0.seen) }
    return CaptureDecision.decide(
      context(offer: nil, selection: copied, fallbackAllowed: false, image: image))
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
    return await save(.image(image, note: ""), recorded, pasteboardChangeCount: changeCount)
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
    for file in PasteboardReader.fileURLs(in: pasteboard) {
      if UTType(filenameExtension: file.pathExtension)?.conforms(to: .image) == true {
        return .file(file)
      }
    }
    return PasteboardReader.imageData(in: pasteboard).map { .data($0.data, $0.type) }
  }

  static func message(for error: Error) -> String {
    if let error = error as? ThoughtsError { return ListModel.message(for: error) }
    return error.localizedDescription
  }
}

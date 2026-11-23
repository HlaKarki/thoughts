import AppKit
import ThoughtsCore
import UniformTypeIdentifiers

final class ShareViewController: NSObject, NSExtensionRequestHandling {
  static let maxItems = 20
  static let appGroup = Bundle.main.object(forInfoDictionaryKey: "ThoughtsAppGroup") as? String
  static let urlScheme = Bundle.main.object(forInfoDictionaryKey: "ThoughtsURLScheme") as? String

  private struct Shared {
    var item: InboxItem
    var attachment: URL?
  }

  func beginRequest(with context: NSExtensionContext) {
    let source = Self.frontmostSource()
    let request = Request(context: context)
    Task { @MainActor in
      await Self.share(source: source, request: request)
    }
  }

  private final class Request: @unchecked Sendable {
    let context: NSExtensionContext

    init(context: NSExtensionContext) {
      self.context = context
    }
  }

  @MainActor
  private static func share(source: Source?, request: Request) async {
    let items = request.context.inputItems.compactMap { $0 as? NSExtensionItem }
    guard let inbox = inbox() else {
      request.context.cancelRequest(
        withError: failure(String(localized: "Thoughts can't receive shared items on this Mac")))
      return
    }
    let scratch = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: scratch) }
    let shared = await collect(items, source: source, scratch: scratch)
    guard !shared.isEmpty else {
      request.context.cancelRequest(
        withError: failure(String(localized: "There was nothing here Thoughts could save")))
      return
    }
    var written = 0
    var problem: String?
    for entry in shared {
      do {
        _ = try inbox.write(entry.item, attachment: entry.attachment)
        written += 1
      } catch ThoughtsError.io(let detail) {
        problem = detail
        break
      } catch {
        problem = error.localizedDescription
        break
      }
    }
    if written > 0 { await openImport() }
    if let problem {
      request.context.cancelRequest(withError: failure(problem))
    } else {
      request.context.completeRequest(returningItems: nil)
    }
  }

  private static func failure(_ message: String) -> NSError {
    NSError(
      domain: "dev.hla.thoughts.share", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }

  private static func inbox() -> Inbox? {
    guard let appGroup, !appGroup.isEmpty,
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroup)
    else { return nil }
    return Inbox(folder: container.appendingPathComponent("Inbox", isDirectory: true))
  }

  private static func frontmostSource() -> Source? {
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
    let source = Source(app: app.localizedName, bundleID: app.bundleIdentifier)
    return source == Source() ? nil : source
  }

  @MainActor
  private static func collect(
    _ items: [NSExtensionItem], source: Source?, scratch: URL
  ) async -> [Shared] {
    var shared: [Shared] = []
    for item in items {
      let providers = item.attachments ?? []
      let title = [item.attributedTitle?.string, item.attributedContentText?.string]
        .compactMap { $0 }.first { !isBlank($0) }
      for provider in providers where shared.count < maxItems {
        if let entry = await read(provider, title: title, scratch: scratch) {
          shared.append(entry)
        }
      }
      if providers.isEmpty, shared.count < maxItems,
        let text = item.attributedContentText?.string, !isBlank(text)
      {
        shared.append(Shared(item: InboxItem(kind: .text, text: text)))
      }
    }
    return shared.map { entry in
      var entry = entry
      entry.item.sourceApp = source
      return entry
    }
  }

  @MainActor
  private static func read(_ provider: NSItemProvider, title: String?, scratch: URL) async
    -> Shared?
  {
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
      let url = await loadURL(provider), url.isFileURL
    {
      return await file(url, provider: provider, scratch: scratch)
    }
    if let type = provider.registeredContentTypes.first(where: { $0.conforms(to: .image) }),
      let data = await loadData(provider, type: type)
    {
      return image(data, type: type, scratch: scratch)
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
      let url = await loadURL(provider)
    {
      if url.isFileURL { return await file(url, provider: provider, scratch: scratch) }
      return Shared(item: InboxItem(kind: .url, url: url, title: title))
    }
    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
      let text = await loadText(provider), !isBlank(text)
    {
      return Shared(item: InboxItem(kind: .text, text: text))
    }
    return nil
  }

  @MainActor
  private static func file(_ url: URL, provider: NSItemProvider, scratch: URL) async -> Shared {
    let item = InboxItem(kind: .file, originalPath: url.path)
    guard UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true,
      let copy = await copyImageFile(provider, name: url.lastPathComponent, scratch: scratch)
    else { return Shared(item: item) }
    return Shared(item: item, attachment: copy)
  }

  @MainActor
  private static func copyImageFile(
    _ provider: NSItemProvider, name: String, scratch: URL
  ) async -> URL? {
    guard
      let identifier = provider.registeredTypeIdentifiers.first(where: {
        UTType($0)?.conforms(to: .image) == true
      })
    else { return nil }
    let target = scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent(name)
    return await withCheckedContinuation { continuation in
      _ = provider.loadFileRepresentation(forTypeIdentifier: identifier) { temporary, _ in
        guard let temporary else {
          continuation.resume(returning: nil)
          return
        }
        do {
          try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
          try FileManager.default.copyItem(at: temporary, to: target)
          continuation.resume(returning: target)
        } catch {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private static func image(_ data: Data, type: UTType, scratch: URL) -> Shared? {
    let ext = type.preferredFilenameExtension ?? "png"
    let file = scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("Image.\(ext)")
    do {
      try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: file)
    } catch {
      return nil
    }
    return Shared(item: InboxItem(kind: .file), attachment: file)
  }

  private static func isBlank(_ text: String) -> Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  @MainActor
  private static func loadURL(_ provider: NSItemProvider) async -> URL? {
    await withCheckedContinuation { continuation in
      _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
    }
  }

  @MainActor
  private static func loadText(_ provider: NSItemProvider) async -> String? {
    await withCheckedContinuation { continuation in
      _ = provider.loadObject(ofClass: String.self) { text, _ in
        continuation.resume(returning: text)
      }
    }
  }

  @MainActor
  private static func loadData(_ provider: NSItemProvider, type: UTType) async -> Data? {
    await withCheckedContinuation { continuation in
      _ = provider.loadDataRepresentation(for: type) { data, _ in
        continuation.resume(returning: data)
      }
    }
  }

  @MainActor
  private static func openImport() async {
    guard let urlScheme, let url = URL(string: "\(urlScheme)://import") else { return }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    _ = try? await NSWorkspace.shared.open(url, configuration: configuration)
  }
}

import AppKit
import ThoughtsCore
import UniformTypeIdentifiers

@MainActor
final class URLHandler {
  var onFailure: (String) -> Void = { _ in }
  private let panel: PanelController
  private let importer: InboxImporter?
  private let save: (NewThought) async throws -> Void
  private let source: () async -> Source?
  private let now: () -> Date

  init(
    panel: PanelController, importer: InboxImporter?,
    save: @escaping (NewThought) async throws -> Void,
    source: @escaping () async -> Source?, now: @escaping () -> Date = Date.init
  ) {
    self.panel = panel
    self.importer = importer
    self.save = save
    self.source = source
    self.now = now
  }

  func handle(_ urls: [URL]) {
    let requests = urls.compactMap(ThoughtsURL.init)
    if requests.count < urls.count {
      onFailure(String(localized: "Thoughts couldn't read that link"))
    }
    for request in requests { perform(request) }
  }

  private func perform(_ request: ThoughtsURL) {
    switch request {
    case .show:
      panel.show()
    case .importInbox:
      handBack()
      guard let task = importer?.importNow() else {
        onFailure(String(localized: "Shared items can't be imported on this Mac"))
        return
      }
      Task { [weak self] in
        await task.value
        self?.handBack()
      }
    case .add(let text):
      handBack()
      add { NewThought(content: .text(text), source: $0, created: $1) }
    case .addImage(let path, let note):
      let file = URL(fileURLWithPath: path)
      guard Self.isImageFile(file) else {
        onFailure(String(localized: "That file isn't an image"))
        return
      }
      handBack()
      add { source, created in
        var new = NewThought.fromFile(file, source: source, created: created)
        new.content = .image(.file(file), note: note)
        return new
      }
    }
  }

  private func add(_ build: @escaping (Source?, Date) -> NewThought) {
    let created = now()
    Task { [weak self] in
      guard let self else { return }
      do {
        try await self.save(build(await self.source(), created))
      } catch {
        self.onFailure(CaptureCoordinator.message(for: error))
      }
      self.handBack()
    }
  }

  private func handBack() {
    guard NSApp.isActive, !panel.isShown,
      !NSApp.windows.contains(where: { $0.isVisible && $0.styleMask.contains(.titled) })
    else { return }
    NSApp.hide(nil)
  }

  static func isImageFile(_ url: URL) -> Bool {
    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey]),
      values.isRegularFile == true
    else { return false }
    return values.contentType?.conforms(to: .image) == true
  }
}

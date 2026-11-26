import AppKit
import ObjectiveC
import Testing
import ThoughtsCore

@testable import Thoughts

final class ImageFileReads: @unchecked Sendable {
  static let shared = ImageFileReads()

  private typealias ImageInit =
    @convention(c) (Unmanaged<NSImage>, Selector, NSURL) -> Unmanaged<NSImage>?

  private let lock = NSLock()
  private var seen: [String: [Bool]] = [:]
  private var arrivals: [String: @Sendable () -> Void] = [:]
  private var original: (method: Method, implementation: IMP)?

  private init() {}

  static func key(_ file: URL) -> String {
    file.resolvingSymlinksInPath().standardizedFileURL.path
  }

  func install() {
    lock.withLock {
      guard original == nil else { return }
      let selector = #selector(NSImage.init(contentsOf:))
      guard let method = class_getInstanceMethod(NSImage.self, selector) else { return }
      let implementation = method_getImplementation(method)
      let call = unsafeBitCast(implementation, to: ImageInit.self)
      let read: @convention(block) (Unmanaged<NSImage>, NSURL) -> Unmanaged<NSImage>? = {
        image, url in
        ImageFileReads.shared.note(url as URL)
        return call(image, selector, url)
      }
      method_setImplementation(method, imp_implementationWithBlock(read))
      original = (method, implementation)
    }
  }

  func uninstall() {
    lock.withLock {
      guard let original else { return }
      method_setImplementation(original.method, original.implementation)
      self.original = nil
    }
  }

  func watch(_ file: URL) {
    lock.withLock { seen[Self.key(file)] = [] }
  }

  func arrive(at file: URL, _ hook: @escaping @Sendable () -> Void) {
    lock.withLock { arrivals[Self.key(file)] = hook }
  }

  func onMain(_ file: URL) -> [Bool] {
    lock.withLock {
      arrivals[Self.key(file)] = nil
      return seen.removeValue(forKey: Self.key(file)) ?? []
    }
  }

  private func note(_ file: URL) {
    let key = Self.key(file)
    let arrival = lock.withLock { arrivals.removeValue(forKey: key) }
    arrival?()
    let main = Thread.isMainThread
    lock.withLock { seen[key]?.append(main) }
  }
}

struct RecordingImageFileReads: SuiteTrait, TestScoping {
  func provideScope(
    for test: Test, testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
    ImageFileReads.shared.install()
    defer { ImageFileReads.shared.uninstall() }
    try await function()
  }
}

extension SuiteTrait where Self == RecordingImageFileReads {
  static var recordingImageFileReads: Self { Self() }
}

@MainActor
@Suite(.recordingImageFileReads)
struct FileReadThreadTests {
  static let reads = ImageFileReads.shared

  static func file(named name: String, in folder: TempFolder, data: Data? = nil) throws -> URL {
    try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
    let file = folder.url.appendingPathComponent(name)
    try (data ?? ListFixture.png()).write(to: file)
    return file
  }

  @Test func anImageFileCopiedInFinderIsReadOffTheMainThreadAndAttachesWhenTheReadLands()
    async throws
  {
    let (fixture, _, board) = try InputModelTests.rig()
    defer { board.releaseGlobally() }
    let folder = TempFolder()
    let file = try Self.file(named: "capture.png", in: folder)
    Self.reads.watch(file)
    try InputModelTests.fill(board, file: file, text: "capture.png", image: true)
    #expect(fixture.input.takeImage(from: board))
    await fixture.input.pasteRead?.value
    #expect(Self.reads.onMain(file) == [false])
    guard case .image(.file(let attached), _) = fixture.input.attachment else {
      Issue.record("expected the image file")
      return
    }
    #expect(attached.lastPathComponent == "capture.png")
    #expect(fixture.input.text.isEmpty)
  }

  @Test func anImageFileThatCannotBeReadIsClaimedAndSaysSo() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
    defer { board.releaseGlobally() }
    let folder = TempFolder()
    let file = try Self.file(named: "broken.png", in: folder, data: Data("not an image".utf8))
    Self.reads.watch(file)
    try InputModelTests.fill(board, file: file, text: "broken.png", image: false)
    #expect(fixture.input.takeImage(from: board))
    await fixture.input.pasteRead?.value
    #expect(Self.reads.onMain(file) == [false])
    #expect(fixture.input.attachment == nil)
    #expect(fixture.input.text.isEmpty)
    #expect(fixture.model.feedback?.text == "That image file can't be read")
  }

  @Test func aReadThatLandsAfterTheClipboardChangedIsDropped() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
    defer { board.releaseGlobally() }
    let folder = TempFolder()
    let file = try Self.file(named: "capture.png", in: folder)
    let hold = Hold()
    Self.reads.arrive(at: file) { hold.pass() }
    try InputModelTests.fill(board, file: file, text: "capture.png", image: false)
    #expect(fixture.input.takeImage(from: board))
    await hold.waitForArrivals(1)
    board.clearContents()
    board.setString("copied while the file was read", forType: .string)
    hold.release()
    await fixture.input.pasteRead?.value
    #expect(fixture.input.attachment == nil)
    #expect(fixture.model.feedback == nil)
  }

  @Test func aReadThatLandsAfterTheThoughtWasAddedIsDropped() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
    defer { board.releaseGlobally() }
    let folder = TempFolder()
    let file = try Self.file(named: "capture.png", in: folder)
    let hold = Hold()
    Self.reads.arrive(at: file) { hold.pass() }
    try InputModelTests.fill(board, file: file, text: "capture.png", image: false)
    #expect(fixture.input.takeImage(from: board))
    await hold.waitForArrivals(1)
    fixture.input.text = "sent before the image showed"
    await fixture.input.submit()
    hold.release()
    await fixture.input.pasteRead?.value
    #expect(fixture.input.attachment == nil)
    let stored = try fixture.store.entries().compactMap(\.thought).map(\.content)
    #expect(stored == [.text("sent before the image showed")])
  }

  @Test func aReadThatLandsAfterAnotherImageWasPastedIsDropped() async throws {
    let (fixture, _, board) = try InputModelTests.rig()
    let other = NSPasteboard(name: NSPasteboard.Name("thoughts.tests.\(UUID().uuidString)"))
    defer {
      board.releaseGlobally()
      other.releaseGlobally()
    }
    let folder = TempFolder()
    let file = try Self.file(named: "capture.png", in: folder)
    let hold = Hold()
    Self.reads.arrive(at: file) { hold.pass() }
    try InputModelTests.fill(board, file: file, text: "capture.png", image: false)
    #expect(fixture.input.takeImage(from: board))
    await hold.waitForArrivals(1)
    try InputModelTests.fill(other, image: true)
    #expect(fixture.input.takeImage(from: other))
    hold.release()
    await fixture.input.pasteRead?.value
    guard case .image(.data, _) = fixture.input.attachment else {
      Issue.record("expected the image pasted second")
      return
    }
  }
}

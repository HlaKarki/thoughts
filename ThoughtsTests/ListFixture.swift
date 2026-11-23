import AppKit
import Foundation
import Testing
import ThoughtsCore

@testable import Thoughts

final class TempFolder {
  let url: URL

  init() {
    url = FileManager.default.temporaryDirectory
      .appendingPathComponent("ThoughtsListTests-\(UUID().uuidString)", isDirectory: true)
  }

  deinit {
    try? FileManager.default.removeItem(at: url)
  }
}

struct StubRecognizer: TextRecognizing {
  let output: String

  init(_ output: String) {
    self.output = output
  }

  func text(in image: URL) throws -> String { output }
}

@MainActor
final class ListFixture {
  let root: URL
  let folder: URL
  let location: StorageLocation
  let model: ListModel
  let input: InputModel
  let store: ThoughtStore
  let sync: IndexSync
  private let cleanup: TempFolder
  private let index: SearchIndex
  private let live: LiveIndex

  static let now = Date(timeIntervalSince1970: 1_795_000_000)

  init(searchDelay: Duration = .zero, recognizer: (any TextRecognizing)? = nil) throws {
    cleanup = TempFolder()
    root = cleanup.url
    folder = root.appendingPathComponent("Thoughts", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let location = StorageLocation(
      appName: "ThoughtsTests", environment: ["THOUGHTS_DIR": folder.path], home: root)
    self.location = location
    let index = try SearchIndex(url: location.indexURL, folder: folder)
    let live = LiveIndex(location: location, index: index, recognizer: nil)
    self.index = index
    self.live = live
    store = ThoughtStore(folder: folder)
    sync = IndexSync(store: store, index: index, recognizer: recognizer)
    model = ListModel(
      index: index, live: live, location: location, searchDelay: searchDelay)
    input = InputModel(location: location, now: { Self.now }, onFailure: { _ in })
  }

  deinit {
    live.stop()
    try? index.close()
  }

  static func settle() async {
    try? await Task.sleep(for: .milliseconds(100))
  }

  func reload() throws {
    _ = try sync.rebuild()
    model.load()
    model.now = Self.now
  }

  @discardableResult
  func addText(
    _ text: String, daysAgo: Double, done: Bool = false, source: Source? = nil
  ) throws -> Thought {
    var thought = try store.add(
      NewThought(
        content: .text(text), source: source,
        created: Self.now.addingTimeInterval(-daysAgo * 86400)))
    if done { thought = try store.setDone(true, for: thought.id, at: Self.now) }
    return thought
  }

  @discardableResult
  func addScreenshot(
    note: String, daysAgo: Double, done: Bool = false, source: Source? = nil
  ) throws -> Thought {
    var thought = try store.add(
      NewThought(
        content: .image(.data(try Self.png(), .png), note: note), source: source,
        created: Self.now.addingTimeInterval(-daysAgo * 86400)))
    if done { thought = try store.setDone(true, for: thought.id, at: Self.now) }
    return thought
  }

  func addUnreadable(name: String, daysAgo: Double) throws {
    let file = folder.appendingPathComponent(name)
    try Data("---\nid: [\n---\nbroken".utf8).write(to: file)
    try FileManager.default.setAttributes(
      [.creationDate: Self.now.addingTimeInterval(-daysAgo * 86400)], ofItemAtPath: file.path)
  }

  static func png() throws -> Data {
    let width = 328
    let height = 208
    let context = try #require(
      CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(gray: 0.62, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(CGColor(gray: 0.88, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 80, height: height))
    context.setFillColor(CGColor(red: 1, green: 0.23, blue: 0.19, alpha: 1))
    context.fill(CGRect(x: 100, y: 60, width: 200, height: 12))
    let image = try #require(context.makeImage())
    let bitmap = NSBitmapImageRep(cgImage: image)
    return try #require(bitmap.representation(using: .png, properties: [:]))
  }

  static func tiff() throws -> Data {
    try #require(NSBitmapImageRep(data: try png())?.tiffRepresentation)
  }
}

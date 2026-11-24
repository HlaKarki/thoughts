import ArgumentParser
import Foundation
import ImageIO
import Synchronization
import Testing
import ThoughtsCore
import UniformTypeIdentifiers

@testable import ThoughtsCommands

private final class FakeRecognizer: TextRecognizing, Sendable {
  private let counter = Mutex(0)

  var calls: Int { counter.withLock { $0 } }

  func text(in image: URL) throws -> String {
    counter.withLock { $0 += 1 }
    return "invoice for the plumber"
  }
}

private final class Lines: Sendable {
  private let lines = Mutex<[String]>([])

  var all: [String] { lines.withLock { $0 } }
  var text: String { all.joined(separator: "\n") }

  func add(_ line: String) {
    lines.withLock { $0.append(line) }
  }

  func reset() {
    lines.withLock { $0 = [] }
  }
}

private final class Scratch {
  let root: URL
  let folder: URL
  let recognizer = FakeRecognizer()
  let out = Lines()
  let err = Lines()
  var stdin: String?

  init(folderPath: String? = nil) {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("command-tests-\(UUID().uuidString)")
    folder = folderPath.map { URL(fileURLWithPath: $0) } ?? root.appendingPathComponent("Thoughts")
    try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    if folderPath == nil {
      try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
  }

  deinit {
    try? FileManager.default.removeItem(at: root)
  }

  var location: StorageLocation {
    StorageLocation(environment: ["THOUGHTS_DIR": folder.path], home: root)
  }

  func environment(recognizer: Bool = true) -> CommandEnvironment {
    let stdin = stdin
    return CommandEnvironment(
      location: location,
      indexURL: location.indexURL,
      recognizer: recognizer ? self.recognizer : nil,
      stdin: { stdin },
      out: { [out] in out.add($0) },
      err: { [err] in err.add($0) }
    )
  }

  @discardableResult
  func run(_ arguments: String...) async -> Int32 {
    await run(arguments)
  }

  func run(_ arguments: [String]) async -> Int32 {
    do {
      let command = try ThoughtsCommand.parseAsRoot(arguments)
      guard let command = command as? any EnvironmentCommand else { return -1 }
      try await command.perform(in: environment())
      return 0
    } catch let code as ExitCode {
      return code.rawValue
    } catch {
      return ExitCode.validationFailure.rawValue
    }
  }

  func writePNG(named name: String = "shot.png") throws -> URL {
    let url = root.appendingPathComponent(name)
    let context = CGContext(
      data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    context.setFillColor(gray: 0.5, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
      data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
    try (data as Data).write(to: url)
    return url
  }
}

private func decodeRecords(_ text: String) throws -> [ThoughtRecord] {
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  return try decoder.decode([ThoughtRecord].self, from: Data(text.utf8))
}

@Test func addThenListPrintsTheThought() async throws {
  let scratch = Scratch()
  #expect(await scratch.run("add", "buy", "oat milk") == 0)
  let id = try #require(scratch.out.all.first)
  #expect(id.count == 8)

  scratch.out.reset()
  #expect(await scratch.run("list") == 0)
  let line = try #require(scratch.out.all.first)
  #expect(scratch.out.all.count == 1)
  #expect(line.hasPrefix(id + "  "))
  #expect(line.hasSuffix("  buy oat milk"))
}

@Test func addReadsStdinWhenNoArguments() async throws {
  let scratch = Scratch()
  scratch.stdin = "first line\nsecond line\n"
  #expect(await scratch.run("add") == 0)
  scratch.out.reset()
  #expect(await scratch.run("list", "--json") == 0)
  let record = try #require(try decodeRecords(scratch.out.text).first)
  #expect(record.text == "first line\nsecond line")
  #expect(record.source?.app == "thoughts CLI")
}

@Test func listJSONDecodesToRecords() async throws {
  let scratch = Scratch()
  let image = try scratch.writePNG()
  await scratch.run("add", "plain text")
  await scratch.run("add", "--image", image.path, "--note", "the receipt")
  scratch.out.reset()
  #expect(await scratch.run("list", "--json") == 0)
  let records = try decodeRecords(scratch.out.text)
  #expect(records.count == 2)
  let text = try #require(records.first { $0.kind == "text" })
  #expect(text.text == "plain text")
  #expect(text.image == nil)
  let shot = try #require(records.first { $0.kind == "image" })
  #expect(shot.note == "the receipt")
  #expect(shot.text == nil)
  #expect(shot.source?.file == image.path)
  let imagePath = try #require(shot.image)
  #expect(FileManager.default.fileExists(atPath: imagePath))
  #expect(shot.file.hasSuffix(".md"))
}

@Test func doneHidesThoughtFromOpenList() async throws {
  let scratch = Scratch()
  await scratch.run("add", "finish taxes")
  let id = try #require(scratch.out.all.first)

  #expect(await scratch.run("done", id) == 0)
  scratch.out.reset()
  await scratch.run("list")
  #expect(scratch.out.all.isEmpty)
  await scratch.run("list", "--done")
  #expect(scratch.out.all.count == 1)

  #expect(await scratch.run("done", id, "--undo") == 0)
  scratch.out.reset()
  await scratch.run("list")
  #expect(scratch.out.all.count == 1)
  scratch.out.reset()
  await scratch.run("list", "--done")
  #expect(scratch.out.all.isEmpty)
}

@Test func pathPrintsImagePathForScreenshot() async throws {
  let scratch = Scratch()
  let image = try scratch.writePNG()
  await scratch.run("add", "--image", image.path)
  let id = try #require(scratch.out.all.first)
  await scratch.run("add", "a text thought")
  let textID = try #require(scratch.out.all.last)

  scratch.out.reset()
  #expect(await scratch.run("path", id) == 0)
  #expect(scratch.out.all.first?.hasSuffix(".png") == true)
  #expect(scratch.out.all.first?.hasPrefix(scratch.folder.path) == true)

  scratch.out.reset()
  #expect(await scratch.run("path", textID) == 0)
  #expect(scratch.out.all.first?.hasSuffix(".md") == true)
}

@Test func unknownIDExitsWithCodeOne() async throws {
  let scratch = Scratch()
  #expect(await scratch.run("show", "zzzzzzzz") == 1)
  #expect(await scratch.run("path", "zzzzzzzz") == 1)
  #expect(await scratch.run("done", "zzzzzzzz") == 1)
  #expect(scratch.err.all.count == 3)
  #expect(scratch.err.all.allSatisfy { !$0.contains("\n") })
}

@Test func unavailableFolderExitsWithCodeThree() async throws {
  let scratch = Scratch(folderPath: "/Volumes/thoughts-test-\(UUID().uuidString)/Thoughts")
  #expect(await scratch.run("list") == 3)
  #expect(await scratch.run("add", "hello") == 3)
  #expect(scratch.err.all.count == 2)
}

@Test func missingFolderFromSettingsExitsWithCodeThreeAndStaysMissing() async throws {
  let scratch = Scratch()
  let location = StorageLocation(environment: [:], home: scratch.root)
  let chosen = scratch.root.appendingPathComponent("Dropbox/Thoughts")
  try location.setFolder(chosen)
  let environment = CommandEnvironment(
    location: location, indexURL: location.indexURL, recognizer: nil, stdin: { nil },
    out: { _ in }, err: { [err = scratch.err] in err.add($0) })
  for arguments in [["list"], ["add", "hello"], ["path", "abcd"], ["done", "abcd"]] {
    let command = try #require(
      try ThoughtsCommand.parseAsRoot(arguments) as? any EnvironmentCommand)
    await #expect(throws: ExitCode(3)) { try await command.perform(in: environment) }
  }
  #expect(scratch.err.all.count == 4)
  #expect(!FileManager.default.fileExists(atPath: chosen.deletingLastPathComponent().path))
}

@Test func searchFindsRecognizedText() async throws {
  let scratch = Scratch()
  let image = try scratch.writePNG()
  await scratch.run("add", "--image", image.path)
  let id = try #require(scratch.out.all.first)
  await scratch.run("add", "something else")

  scratch.out.reset()
  #expect(await scratch.run("search", "plumber") == 0)
  #expect(scratch.out.all.count == 1)
  #expect(scratch.out.all.first?.hasPrefix(id) == true)
  #expect(scratch.recognizer.calls == 1)
}

@Test func listNeverCallsTheRecognizer() async throws {
  let scratch = Scratch()
  let image = try scratch.writePNG()
  await scratch.run("add", "--image", image.path)
  scratch.out.reset()
  #expect(await scratch.run("list") == 0)
  #expect(
    await scratch.run("show", try #require(scratch.out.all.first?.prefix(8)).description) == 0)
  #expect(scratch.recognizer.calls == 0)
}

@Test func usageErrorsExitWithTheUsageCode() async throws {
  let scratch = Scratch()
  let notImage = scratch.root.appendingPathComponent("notes.txt")
  try "words".write(to: notImage, atomically: true, encoding: .utf8)
  let usage = ExitCode.validationFailure.rawValue
  #expect(await scratch.run("add", "--image", notImage.path) == usage)
  #expect(await scratch.run("add") == usage)
  #expect(await scratch.run("add", "--note", "orphan", "text") == usage)
  #expect(await scratch.run("bogus") == usage)
}

@Test func exitCodesFollowTheErrorKind() {
  let id = ThoughtID(rawValue: "abcd1234")!
  #expect(exitCode(for: ThoughtsError.notFound("x")) == 1)
  #expect(exitCode(for: ThoughtsError.ambiguous("ab", [id])) == 1)
  #expect(exitCode(for: ThoughtsError.storageUnavailable("/Volumes/x")) == 3)
  #expect(exitCode(for: ThoughtsError.io("disk full")) == 4)
  #expect(exitCode(for: ThoughtsError.changedOnDisk(id)) == 4)
  #expect(exitCode(for: ThoughtsError.deletedOnDisk(id)) == 4)
  #expect(exitCode(for: ThoughtsError.folderNotEmpty(["a"])) == 4)
  #expect(exitCode(for: ThoughtsError.clipboardChanged) == 4)
  #expect(exitCode(for: CocoaError(.fileReadNoPermission)) == 4)
  #expect(errorMessage(for: ThoughtsError.io("one\ntwo")) == "one two")
}

@Test func bundleNameFollowsSymlinkedExecutable() throws {
  let scratch = Scratch()
  let helpers = scratch.root.appendingPathComponent("Dev.app/Contents/Helpers")
  try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
  let plist = ["CFBundleName": "Thoughts Dev"]
  try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    .write(to: helpers.deletingLastPathComponent().appendingPathComponent("Info.plist"))
  let tool = helpers.appendingPathComponent("thoughts")
  try Data().write(to: tool)
  let bin = scratch.root.appendingPathComponent("bin")
  try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
  let link = bin.appendingPathComponent("thoughts")
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: tool)

  #expect(CommandEnvironment.appName(forExecutable: tool) == "Thoughts Dev")
  #expect(CommandEnvironment.appName(forExecutable: link) == "Thoughts Dev")
  let loose = scratch.root.appendingPathComponent("loose")
  try Data().write(to: loose)
  #expect(CommandEnvironment.appName(forExecutable: loose) == "Thoughts")
}

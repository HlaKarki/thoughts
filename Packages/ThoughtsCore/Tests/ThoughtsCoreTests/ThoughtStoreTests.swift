import Foundation
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers

@testable import ThoughtsCore

private final class Trashed: Sendable {
  private let urls = Mutex<[URL]>([])

  func record(_ url: URL) {
    urls.withLock { $0.append(url) }
  }

  var all: [URL] { urls.withLock { $0 } }
}

private final class Fixture {
  let scratch: URL
  let folder: URL
  let trashed = Trashed()
  let store: ThoughtStore

  init() {
    scratch = FileManager.default.temporaryDirectory
      .appendingPathComponent("thought-store-tests-\(UUID().uuidString)")
    folder = scratch.appendingPathComponent("Thoughts")
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let trashed = trashed
    store = ThoughtStore(folder: folder, trash: { trashed.record($0) })
  }

  deinit {
    try? FileManager.default.removeItem(at: scratch)
  }

  func write(_ name: String, _ text: String, in directory: URL? = nil) -> URL {
    let url = (directory ?? folder).appendingPathComponent(name)
    try! text.write(to: url, atomically: false, encoding: .utf8)
    return url
  }

  func write(_ name: String, bytes: [UInt8]) -> URL {
    let url = folder.appendingPathComponent(name)
    try! Data(bytes).write(to: url)
    return url
  }

  func text(_ url: URL) -> String {
    try! String(contentsOf: url, encoding: .utf8)
  }

  func names() -> [String] {
    try! FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
  }

  func addText(_ text: String, created: Date = Date()) -> Thought {
    try! store.add(NewThought(content: .text(text), source: nil, created: created))
  }

  func writeFrontMatter(id: String, extra: String = "", body: String = "body") -> URL {
    write(
      "20261122-101010-\(id).md",
      "---\nid: \(id)\ncreated: 2026-11-22T10:10:10.000+00:00\n\(extra)---\n\(body)\n")
  }
}

private func grayImage(width: Int, height: Int) -> CGImage {
  let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
  context.setFillColor(gray: 0.5, alpha: 1)
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  return context.makeImage()!
}

private func encoded(_ image: CGImage, as type: UTType) -> Data {
  let data = NSMutableData()
  let destination = CGImageDestinationCreateWithData(
    data, type.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, image, nil)
  precondition(CGImageDestinationFinalize(destination))
  return data as Data
}

private func pixelSize(of url: URL) -> (width: Int, height: Int)? {
  guard
    let source = CGImageSourceCreateWithURL(url as CFURL, nil),
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
    let width = properties[kCGImagePropertyPixelWidth] as? Int,
    let height = properties[kCGImagePropertyPixelHeight] as? Int
  else { return nil }
  return (width, height)
}

@Test func addsTextThoughtAsMarkdownFile() throws {
  let fx = Fixture()
  let thought = try fx.store.add(
    NewThought(content: .text("buy milk"), source: nil, created: Date()))
  let name = thought.file.lastPathComponent
  #expect(name.wholeMatch(of: /\d{8}-\d{6}-[0-9a-z]{8}\.md/) != nil)
  #expect(name.hasSuffix("-\(thought.id.rawValue).md"))
  #expect(fx.names() == [name])
  #expect(thought.content == .text("buy milk"))
  #expect(try fx.store.entry(at: thought.file) == .thought(thought))
}

@Test func addsLargeClipboardTIFFAsPNG() throws {
  let fx = Fixture()
  let tiff = encoded(grayImage(width: 7680, height: 4320), as: .tiff)
  let thought = try fx.store.add(
    NewThought(content: .image(.data(tiff, .tiff), note: "wide"), source: nil, created: Date()))
  let image = try #require(fx.store.imageURL(of: thought))
  #expect(image.pathExtension == "png")
  #expect(
    image.deletingPathExtension().lastPathComponent
      == thought.file.deletingPathExtension().lastPathComponent)
  let size = try #require(pixelSize(of: image))
  #expect(size.width == 7680)
  #expect(size.height == 4320)
  #expect(fx.names().count == 2)
  #expect(thought.content == .image(fileName: image.lastPathComponent, note: "wide"))
}

@Test func addsImageFileKeepingItsType() throws {
  let fx = Fixture()
  let original = fx.scratch.appendingPathComponent("photo.jpg")
  try encoded(grayImage(width: 40, height: 30), as: .jpeg).write(to: original)
  let thought = try fx.store.add(
    NewThought.fromFile(original, source: nil, created: Date()))
  let image = try #require(fx.store.imageURL(of: thought))
  #expect(image.pathExtension == "jpg")
  #expect(try Data(contentsOf: image) == Data(contentsOf: original))
  #expect(FileManager.default.fileExists(atPath: original.path))
  #expect(thought.source?.file == original.path)
}

@Test func nonImageFileBecomesPathThought() throws {
  let fx = Fixture()
  let report = fx.write("report.pdf", "%PDF-1.4", in: fx.scratch)
  let new = NewThought.fromFile(report, source: Source(app: "Finder"), created: Date())
  guard case .text(let text) = new.content else {
    Issue.record("expected a text thought")
    return
  }
  #expect(text == report.path)
  #expect(new.source?.file == report.path)
  #expect(new.source?.app == "Finder")
  let thought = try fx.store.add(new)
  #expect(thought.content == .text(report.path))
  #expect(thought.source?.file == report.path)
  #expect(fx.names().count == 1)
}

@Test func leavesNoTemporaryFiles() throws {
  let fx = Fixture()
  let png = encoded(grayImage(width: 20, height: 20), as: .png)
  let text = fx.addText("one")
  let shot = try fx.store.add(
    NewThought(content: .image(.data(png, .png), note: ""), source: nil, created: Date()))
  _ = try fx.store.setText("two", of: text.id, expected: text.version)
  _ = try fx.store.setDone(true, for: shot.id, at: Date())
  _ = try fx.store.clearDone()
  #expect(throws: ThoughtsError.self) {
    try fx.store.add(
      NewThought(
        content: .image(.data(Data("nope".utf8), .tiff), note: ""), source: nil, created: Date()))
  }
  let all = try FileManager.default.contentsOfDirectory(atPath: fx.folder.path)
  #expect(all.count == 3)
  #expect(all.allSatisfy { !$0.contains(".tmp-") })
}

@Test func entriesSortByCreatedAndIncludeMalformed() throws {
  let fx = Fixture()
  let base = Date(timeIntervalSince1970: 1_700_000_000)
  let late = fx.addText("late", created: base.addingTimeInterval(200))
  let early = fx.addText("early", created: base)
  let tieA = fx.addText("tie a", created: base.addingTimeInterval(100))
  let tieB = fx.addText("tie b", created: base.addingTimeInterval(100))
  let broken = fx.write("broken.md", "---\nno closing line\n")
  let entries = try fx.store.entries()
  #expect(entries.count == 5)
  let ties = [tieA, tieB].sorted { $0.file.lastPathComponent < $1.file.lastPathComponent }
  let expected: [URL] = [early.file, ties[0].file, ties[1].file, late.file, broken]
  let actual = entries.map { entry -> URL in
    switch entry {
    case .thought(let thought): thought.file
    case .malformed(let file, _): file
    }
  }
  #expect(actual == expected)
  guard case .malformed(_, let reason) = entries[4] else {
    Issue.record("expected the last entry to be malformed")
    return
  }
  #expect(!reason.isEmpty)
}

@Test func matchesUniquePrefix() throws {
  let fx = Fixture()
  _ = fx.writeFrontMatter(id: "abcd1234")
  _ = fx.writeFrontMatter(id: "abcd5678")
  let other = fx.writeFrontMatter(id: "wxyz9999")
  _ = fx.write("bad.md", "---\nbroken")
  #expect(try fx.store.thought(matching: "wxyz").file == other)
  #expect(try fx.store.thought(matching: "wxyz9999").id.rawValue == "wxyz9999")
  #expect(try fx.store.thought(matching: "abcd5").id.rawValue == "abcd5678")
  do {
    _ = try fx.store.thought(matching: "abcd")
    Issue.record("expected an ambiguous error")
  } catch ThoughtsError.ambiguous(let prefix, let ids) {
    #expect(prefix == "abcd")
    #expect(Set(ids.map(\.rawValue)) == ["abcd1234", "abcd5678"])
  }
  #expect(throws: ThoughtsError.notFound("zzzz")) { try fx.store.thought(matching: "zzzz") }
  #expect(throws: ThoughtsError.notFound("wxy")) { try fx.store.thought(matching: "wxy") }
}

@Test func setTextRefusesFileChangedOnDisk() throws {
  let fx = Fixture()
  let thought = fx.addText("first")
  try "---\nid: \(thought.id)\n---\nedited elsewhere with more text\n"
    .write(to: thought.file, atomically: false, encoding: .utf8)
  #expect(throws: ThoughtsError.changedOnDisk(thought.id)) {
    try fx.store.setText("mine", of: thought.id, expected: thought.version)
  }
  #expect(fx.text(thought.file).contains("edited elsewhere"))
}

@Test func setTextOnDeletedFileThrows() throws {
  let fx = Fixture()
  let thought = fx.addText("first")
  try FileManager.default.removeItem(at: thought.file)
  #expect(throws: ThoughtsError.deletedOnDisk(thought.id)) {
    try fx.store.setText("mine", of: thought.id, expected: thought.version)
  }
}

@Test func setTextEditsTextAndImageNote() throws {
  let fx = Fixture()
  let text = fx.addText("first")
  let edited = try fx.store.setText("second", of: text.id, expected: text.version)
  #expect(edited.content == .text("second"))
  #expect(try fx.store.entry(at: text.file) == .thought(edited))

  let png = encoded(grayImage(width: 20, height: 20), as: .png)
  let shot = try fx.store.add(
    NewThought(content: .image(.data(png, .png), note: "old"), source: nil, created: Date()))
  let renoted = try fx.store.setText("new note", of: shot.id, expected: shot.version)
  guard case .image(let name, let note) = renoted.content else {
    Issue.record("expected an image thought")
    return
  }
  #expect(note == "new note")
  #expect(name == shot.file.deletingPathExtension().lastPathComponent + ".png")
  #expect(try fx.store.entry(at: shot.file) == .thought(renoted))
}

@Test func setDoneWritesTimeAndUndoUnclears() throws {
  let fx = Fixture()
  let thought = fx.addText("do it")
  let date = Date(timeIntervalSince1970: 1_795_000_500.1234)
  let done = try fx.store.setDone(true, for: thought.id, at: date)
  #expect(done.done == FrontMatterCodec.canonical(date))
  #expect(try fx.store.entry(at: thought.file) == .thought(done))

  #expect(try fx.store.clearDone() == [thought.id])
  guard case .thought(let cleared) = try fx.store.entry(at: thought.file) else {
    Issue.record("expected a thought")
    return
  }
  #expect(cleared.cleared)

  let undone = try fx.store.setDone(false, for: thought.id, at: date)
  #expect(undone.done == nil)
  #expect(!undone.cleared)
  #expect(try fx.store.entry(at: thought.file) == .thought(undone))
}

@Test func clearDoneMarksOnlyDoneThoughts() throws {
  let fx = Fixture()
  let first = fx.addText("a", created: Date(timeIntervalSince1970: 1_700_000_000))
  let open = fx.addText("b", created: Date(timeIntervalSince1970: 1_700_000_100))
  let second = fx.addText("c", created: Date(timeIntervalSince1970: 1_700_000_200))
  _ = try fx.store.setDone(true, for: first.id, at: Date())
  _ = try fx.store.setDone(true, for: second.id, at: Date())
  #expect(try fx.store.clearDone() == [first.id, second.id])
  #expect(try fx.store.clearDone() == [])
  for case .thought(let thought) in try fx.store.entries() {
    #expect(thought.cleared == (thought.id != open.id))
  }
  #expect(!fx.text(open.file).contains("cleared: true"))
}

@Test func deleteTrashesMarkdownAndImage() throws {
  let fx = Fixture()
  let png = encoded(grayImage(width: 20, height: 20), as: .png)
  let shot = try fx.store.add(
    NewThought(content: .image(.data(png, .png), note: ""), source: nil, created: Date()))
  let text = fx.addText("keep me")
  try fx.store.delete([shot.id, ThoughtID(rawValue: "unknown1")!])
  let image = try #require(fx.store.imageURL(of: shot))
  #expect(fx.trashed.all == [shot.file, image])
  #expect(!fx.trashed.all.contains(text.file))
}

@Test func plainFileGetsFrontMatterOnFirstChange() throws {
  let fx = Fixture()
  let note = fx.write("note.md", "just words\n")
  #expect(fx.text(note) == "just words\n")
  let thought = try fx.store.thought(matching: "note")
  #expect(thought.content == .text("just words"))
  _ = try fx.store.setDone(true, for: thought.id, at: Date())
  #expect(fx.names() == ["note.md"])
  let text = fx.text(note)
  #expect(text.hasPrefix("---\n"))
  #expect(text.contains("id: note"))
  #expect(text.hasSuffix("---\njust words\n"))
}

@Test func malformedFileIsNeverWritten() throws {
  let fx = Fixture()
  let unclosed = fx.write("unclosed.md", "---\nid: unclosed\nno closing line\n")
  let wrongType = fx.write("wrongtype.md", "---\ncleared: maybe\n---\nbody\n")
  let binary = fx.write("binary.md", bytes: [0x23, 0x20, 0xFF, 0xFE, 0x80, 0x0A])
  let good = fx.addText("good")
  _ = try fx.store.setDone(true, for: good.id, at: Date())
  let before = [unclosed, wrongType, binary].map { try! Data(contentsOf: $0) }

  #expect(try fx.store.clearDone() == [good.id])
  try fx.store.delete(["unclosed", "wrongtype", "binary"].map { ThoughtID(rawValue: $0)! })
  #expect(throws: ThoughtsError.changedOnDisk(ThoughtID(rawValue: "unclosed")!)) {
    try fx.store.setDone(true, for: ThoughtID(rawValue: "unclosed")!, at: Date())
  }

  let after = [unclosed, wrongType, binary].map { try! Data(contentsOf: $0) }
  #expect(before == after)
  #expect(fx.trashed.all.isEmpty)
  let malformed = try fx.store.entries().filter {
    if case .malformed = $0 { return true }
    return false
  }
  #expect(malformed.count == 3)
}

@Test func rewritesKeepUnknownKeys() throws {
  let fx = Fixture()
  let file = fx.writeFrontMatter(id: "tagged01", extra: "tags: [a, b]\n")
  let id = ThoughtID(rawValue: "tagged01")!
  _ = try fx.store.setDone(true, for: id, at: Date())
  let text = fx.text(file)
  #expect(text.contains("tags:"))
  #expect(text.contains("- a") || text.contains("[a, b]"))
}

@Test func rewritesKeepUnknownSourceKeys() throws {
  let fx = Fixture()
  let file = fx.writeFrontMatter(id: "sourced1", extra: "source: {app: Code, line: 12}\n")
  let thought = try fx.store.thought(matching: "sourced1")
  _ = try fx.store.setText("changed", of: thought.id, expected: thought.version)
  let text = fx.text(file)
  #expect(text.contains("line: 12"))
  #expect(text.contains("app: Code"))
  #expect(text.hasSuffix("---\nchanged\n"))
}

@Test func readsFileWithByteOrderMark() throws {
  let fx = Fixture()
  _ = fx.write(
    "20261122-101010-bomfile1.md",
    "\u{FEFF}---\nid: bomfile1\ncreated: 2026-11-22T10:10:10.000+00:00\n---\nbody\n")
  #expect(try fx.store.thought(matching: "bomfile1").content == .text("body"))
}

@Test func refusesAMissingFolder() throws {
  let store = ThoughtStore(
    folder: FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID())"))
  #expect(throws: ThoughtsError.self) { try store.entries() }
  #expect(throws: ThoughtsError.self) {
    try store.add(NewThought(content: .text("x"), source: nil, created: Date()))
  }
}

@Test func entriesSkipVanishedFilesAndFlagUnreadableOnes() throws {
  let fx = Fixture()
  let good = fx.addText("good")
  let dangling = fx.folder.appendingPathComponent("dangling.md")
  try FileManager.default.createSymbolicLink(
    atPath: dangling.path, withDestinationPath: fx.scratch.appendingPathComponent("gone.md").path)
  let locked = fx.write("locked.md", "---\nid: locked01\n---\nsecret\n")
  try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)
  defer {
    try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path)
  }
  let entries = try fx.store.entries()
  #expect(entries.count == 2)
  #expect(entries.contains(.thought(good)))
  let reasons = entries.compactMap { entry -> String? in
    if case .malformed(let file, let reason) = entry, file == locked { return reason }
    return nil
  }
  #expect(reasons.count == 1)
  #expect(throws: ThoughtsError.notFound("dangling.md")) { try fx.store.entry(at: dangling) }
  #expect(try fx.store.thought(matching: good.id.rawValue) == good)
}

@Test func fileNamesStayGregorianWhateverTheCalendar() {
  let zone = TimeZone(secondsFromGMT: 0)!
  var utc = Calendar(identifier: .gregorian)
  utc.timeZone = zone
  let date = utc.date(
    from: DateComponents(year: 2026, month: 11, day: 22, hour: 20, minute: 3, second: 28))!
  let id = ThoughtID(rawValue: "ke16cx5j")!
  for identifier in [Calendar.Identifier.japanese, .buddhist, .gregorian, .islamicUmmAlQura] {
    var calendar = Calendar(identifier: identifier)
    calendar.timeZone = zone
    calendar.locale = Locale(identifier: "ar_SA@numbers=arab")
    #expect(
      FileNaming.baseName(created: date, id: id, calendar: calendar) == "20261122-200328-ke16cx5j")
  }
}

@Test func copiesReadOnlyAndLockedSourceImages() throws {
  let fx = Fixture()
  let jpeg = encoded(grayImage(width: 40, height: 30), as: .jpeg)
  let readOnly = fx.scratch.appendingPathComponent("readonly.jpg")
  let locked = fx.scratch.appendingPathComponent("locked.jpg")
  try jpeg.write(to: readOnly)
  try jpeg.write(to: locked)
  try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: readOnly.path)
  try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: locked.path)
  defer {
    try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: locked.path)
  }
  for source in [readOnly, locked] {
    let thought = try fx.store.add(NewThought.fromFile(source, source: nil, created: Date()))
    let image = try #require(fx.store.imageURL(of: thought))
    #expect(try Data(contentsOf: image) == jpeg)
    #expect(FileManager.default.isWritableFile(atPath: image.path))
  }
  let all = try FileManager.default.contentsOfDirectory(atPath: fx.folder.path)
  #expect(all.count == 4)
  #expect(all.allSatisfy { !$0.contains(".tmp-") })
}

@Test func deleteTrashesOnlyTheImageSharingItsBaseName() throws {
  let fx = Fixture()
  let victim = fx.writeFrontMatter(id: "victim01")
  let attacker = fx.write(
    "20261122-101010-attack01.md",
    "---\nid: attack01\ncreated: 2026-11-22T10:10:10.000+00:00\nimage: 20261122-101010-victim01.md\n---\nnote\n"
  )
  try fx.store.delete([ThoughtID(rawValue: "attack01")!])
  #expect(fx.trashed.all == [attacker])
  #expect(!fx.trashed.all.contains(victim))
}

@Test func duplicateIDCopyIsMalformedAndNeverTouched() throws {
  let fx = Fixture()
  let original = fx.writeFrontMatter(id: "dupe0001")
  let copy = fx.write(
    "20261122-101010-dupe0001 copy.md", try String(contentsOf: original, encoding: .utf8))
  let id = ThoughtID(rawValue: "dupe0001")!
  let copyBytes = try Data(contentsOf: copy)

  let entries = try fx.store.entries()
  #expect(entries.count == 2)
  guard case .malformed(copy, let reason) = entries.first(where: { $0.isMalformed(copy) }) else {
    Issue.record("expected the copy to be malformed")
    return
  }
  #expect(reason.contains(original.lastPathComponent))

  let found = try fx.store.thought(matching: "dupe0001")
  #expect(found.file == original)
  let edited = try fx.store.setText("edited", of: id, expected: found.version)
  #expect(edited.file == original)
  _ = try fx.store.setDone(true, for: id, at: Date())
  #expect(try fx.store.clearDone() == [id])
  try fx.store.delete([id])
  #expect(fx.trashed.all == [original])
  #expect(try Data(contentsOf: copy) == copyBytes)
}

@Test func duplicateIDWithoutASingleOwnerMakesEveryFileMalformed() throws {
  let fx = Fixture()
  let body = "---\nid: shared01\ncreated: 2026-11-22T10:10:10.000+00:00\n---\nbody\n"
  _ = fx.write("a-shared01.md", body)
  _ = fx.write("b-shared01.md", body)
  _ = fx.write("renamed.md", body)
  let entries = try fx.store.entries()
  #expect(entries.count == 3)
  #expect(entries.allSatisfy { if case .malformed = $0 { true } else { false } })
  #expect(throws: ThoughtsError.notFound("shared01")) { try fx.store.thought(matching: "shared01") }
}

extension ThoughtEntry {
  fileprivate func isMalformed(_ url: URL) -> Bool {
    if case .malformed(let file, _) = self { return file == url }
    return false
  }
}

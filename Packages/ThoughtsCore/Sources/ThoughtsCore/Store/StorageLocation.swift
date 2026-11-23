import CryptoKit
import Darwin
import Foundation

public struct StorageLocation: Sendable {
  private let appName: String
  private let environment: [String: String]
  private let home: URL

  public init(
    appName: String = "Thoughts",
    environment: [String: String] = ProcessInfo.processInfo.environment,
    home: URL = FileManager.default.homeDirectoryForCurrentUser
  ) {
    self.appName = appName
    self.environment = environment
    self.home = home
  }

  public var supportFolder: URL {
    home.appendingPathComponent("Library/Application Support/\(appName)", isDirectory: true)
  }

  public var settingsFile: URL {
    supportFolder.appendingPathComponent("settings.json")
  }

  public var indexURL: URL {
    guard let custom = environmentFolder else {
      return supportFolder.appendingPathComponent("index.sqlite")
    }
    let digest = SHA256.hash(data: Data(custom.path.utf8))
    let name = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    return supportFolder.appendingPathComponent("Indexes", isDirectory: true)
      .appendingPathComponent("\(name).sqlite")
  }

  public func configuredFolder() throws -> URL {
    try environmentFolder ?? settingsFolder() ?? defaultFolder
  }

  public func resolve() throws -> URL {
    let folder = try configuredFolder()
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) {
      guard isDirectory.boolValue else { throw ThoughtsError.io("\(folder.path) is not a folder") }
      return folder
    }
    if Self.isOnVolume(folder) { throw ThoughtsError.storageUnavailable(folder.path) }
    try Self.createFolder(folder)
    return folder
  }

  public func setFolder(_ folder: URL) throws {
    try writeSettings(folder: expand(folder.path))
  }

  public func move(to destination: URL) throws {
    try move(to: destination, rename: Self.renameFolder)
  }

  func move(
    to destination: URL, rename: (URL, URL) -> Int32, afterCopy: () -> Void = {},
    afterVerify: () -> Void = {}
  ) throws {
    guard environmentFolder == nil else {
      throw ThoughtsError.io("The folder can't move while THOUGHTS_DIR is set")
    }
    let source = try resolve().resolvingSymlinksInPath()
    let target = expand(destination.path)
    let resolvedTarget = target.resolvingSymlinksInPath().path
    let linkToSource = Self.isSymlink(target)
    if linkToSource {
      guard resolvedTarget == source.path else {
        throw ThoughtsError.folderNotEmpty([target.lastPathComponent])
      }
    } else {
      guard resolvedTarget != source.path else { return }
      guard !resolvedTarget.hasPrefix(source.path + "/") else {
        throw ThoughtsError.io("A folder can't move into itself")
      }
    }
    let foreign = try Self.foreignNames(in: source)
    guard foreign.isEmpty else { throw ThoughtsError.folderNotEmpty(foreign) }
    if !linkToSource { try checkDestination(target) }

    if linkToSource {
      do {
        try FileManager.default.removeItem(at: target)
      } catch {
        throw ThoughtsError.io(error.localizedDescription)
      }
    }
    do {
      switch rename(source, target) {
      case 0:
        try commitRename(from: source, to: target)
      case EXDEV:
        try commitCopy(
          from: source, to: target, afterCopy: afterCopy, afterVerify: afterVerify)
      case let code:
        throw ThoughtsError.io(String(cString: strerror(code)))
      }
    } catch {
      if linkToSource, Self.isAbsent(target) {
        try? FileManager.default.createSymbolicLink(at: target, withDestinationURL: source)
      }
      throw error
    }
  }

  private var defaultFolder: URL {
    home.appendingPathComponent(appName, isDirectory: true)
  }

  private var environmentFolder: URL? {
    guard let path = environment["THOUGHTS_DIR"], !path.isEmpty else { return nil }
    return expand(path)
  }

  private func settingsFolder() throws -> URL? {
    guard let value = try readSettings()["folder"] else { return nil }
    guard let path = value as? String else {
      throw ThoughtsError.io("\(settingsFile.path) has a folder that is not text")
    }
    return path.isEmpty ? nil : expand(path)
  }

  private func expand(_ path: String) -> URL {
    var expanded = path
    if path == "~" {
      expanded = home.path
    } else if path.hasPrefix("~/") {
      expanded = home.path + path.dropFirst()
    }
    return URL(fileURLWithPath: expanded).standardized
  }

  private func readSettings() throws -> [String: Any] {
    guard FileManager.default.fileExists(atPath: settingsFile.path) else { return [:] }
    do {
      let data = try Data(contentsOf: settingsFile)
      guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw ThoughtsError.io("\(settingsFile.path) is not a settings object")
      }
      return settings
    } catch let error as ThoughtsError {
      throw error
    } catch {
      throw ThoughtsError.io(
        "\(settingsFile.path) can't be read: \(error.localizedDescription)")
    }
  }

  private func writeSettings(folder: URL) throws {
    var settings = try readSettings()
    settings["folder"] = folder.path
    do {
      let data = try JSONSerialization.data(
        withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
      try Self.createFolder(supportFolder)
      let target: AtomicFile.Target =
        (try? AtomicFile.info(at: settingsFile)).map { .replacing($0.version) } ?? .new
      try AtomicFile.write(data, to: settingsFile, target: target)
    } catch let error as ThoughtsError {
      throw error
    } catch let error as AtomicFileError {
      throw ThoughtsError.io("\(settingsFile.path) changed while saving: \(error)")
    } catch {
      throw ThoughtsError.io(error.localizedDescription)
    }
  }

  private func checkDestination(_ target: URL) throws {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory) {
      guard isDirectory.boolValue else { throw ThoughtsError.io("\(target.path) is not a folder") }
      let names = try Self.names(in: target)
      guard names.isEmpty else { throw ThoughtsError.folderNotEmpty(names.sorted()) }
      return
    }
    let parent = target.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: parent.path) {
      if Self.isOnVolume(parent) { throw ThoughtsError.storageUnavailable(target.path) }
      try Self.createFolder(parent)
    }
  }

  private func commitRename(from source: URL, to target: URL) throws {
    do {
      try FileManager.default.createSymbolicLink(at: source, withDestinationURL: target)
    } catch {
      _ = Darwin.rename(target.path, source.path)
      throw ThoughtsError.io(error.localizedDescription)
    }
    do {
      try writeSettings(folder: target)
    } catch {
      try? FileManager.default.removeItem(at: source)
      _ = Darwin.rename(target.path, source.path)
      throw error
    }
  }

  private func commitCopy(
    from source: URL, to target: URL, afterCopy: () -> Void, afterVerify: () -> Void
  ) throws {
    let fileManager = FileManager.default
    let createdTarget = !fileManager.fileExists(atPath: target.path)
    var copied: [String] = []
    var snapshot: [(String, FileVersion)] = []
    do {
      snapshot = try Self.snapshot(of: source)
      try Self.createFolder(target)
      for (name, _) in snapshot {
        try fileManager.copyItem(
          at: source.appendingPathComponent(name), to: target.appendingPathComponent(name))
        copied.append(name)
      }
      afterCopy()
      try Self.verifyCopy(snapshot, from: source, in: target)
      try writeSettings(folder: target)
    } catch {
      if createdTarget {
        try? fileManager.removeItem(at: target)
      } else {
        for name in copied { try? fileManager.removeItem(at: target.appendingPathComponent(name)) }
      }
      throw error
    }
    afterVerify()
    for (name, version) in snapshot {
      let file = source.appendingPathComponent(name)
      if (try? AtomicFile.info(at: file).version) == version {
        try? fileManager.removeItem(at: file)
      }
    }
    guard rmdir(source.path) == 0 else {
      let left = ((try? Self.names(in: source)) ?? []).sorted().joined(separator: ", ")
      throw ThoughtsError.io(
        "Your thoughts are now in \(target.path), but the old folder was kept because it still holds \(left)"
      )
    }
    do {
      try fileManager.createSymbolicLink(at: source, withDestinationURL: target)
    } catch {
      throw ThoughtsError.io(
        "Your thoughts are now in \(target.path), but no link was left at the old path: \(error.localizedDescription)"
      )
    }
  }

  private static func renameFolder(_ source: URL, _ target: URL) -> Int32 {
    Darwin.rename(source.path, target.path) == 0 ? 0 : errno
  }

  private static func isOnVolume(_ url: URL) -> Bool {
    url.path.hasPrefix("/Volumes/")
  }

  private static func createFolder(_ url: URL) throws {
    do {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    } catch {
      throw ThoughtsError.io(error.localizedDescription)
    }
  }

  private static func names(in folder: URL) throws -> [String] {
    do {
      return try FileManager.default.contentsOfDirectory(atPath: folder.path)
    } catch {
      throw ThoughtsError.io(error.localizedDescription)
    }
  }

  private static func snapshot(of folder: URL) throws -> [(String, FileVersion)] {
    try names(in: folder).map { name in
      (name, try AtomicFile.info(at: folder.appendingPathComponent(name)).version)
    }
  }

  private static func verifyCopy(
    _ snapshot: [(String, FileVersion)], from source: URL, in target: URL
  ) throws {
    for (name, version) in snapshot {
      let current = try? AtomicFile.info(at: source.appendingPathComponent(name)).version
      let copy = try? AtomicFile.info(at: target.appendingPathComponent(name)).version
      guard current == version, copy?.size == version.size else {
        throw ThoughtsError.io("\(name) changed while it was being copied")
      }
    }
  }

  private static func isSymlink(_ url: URL) -> Bool {
    (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
  }

  private static func isAbsent(_ url: URL) -> Bool {
    var info = stat()
    return lstat(url.path, &info) != 0
  }

  private static func foreignNames(in folder: URL) throws -> [String] {
    let names = try names(in: folder)
    let documents = Set(names.filter { $0.hasSuffix(".md") }.map(baseName))
    return names.filter { name in
      if name.hasSuffix(".md") || name == ".DS_Store" || isTemporary(name) { return false }
      var isDirectory: ObjCBool = false
      let path = folder.appendingPathComponent(name).path
      _ = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
      let isImage =
        !isDirectory.boolValue && name.contains(".") && documents.contains(baseName(name))
      return !isImage
    }.sorted()
  }

  private static func baseName(_ name: String) -> String {
    (name as NSString).deletingPathExtension
  }

  private static func isTemporary(_ name: String) -> Bool {
    guard name.hasPrefix("."), let range = name.range(of: ".tmp-", options: .backwards) else {
      return false
    }
    return UUID(uuidString: String(name[range.upperBound...])) != nil
  }
}

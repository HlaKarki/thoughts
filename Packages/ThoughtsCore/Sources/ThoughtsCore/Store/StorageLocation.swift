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

  public func resolve() throws -> URL {
    let folder = try environmentFolder ?? settingsFolder() ?? defaultFolder
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

  func move(to destination: URL, rename: (URL, URL) -> Int32) throws {
    let source = try resolve().resolvingSymlinksInPath()
    let target = expand(destination.path)
    let resolvedTarget = target.resolvingSymlinksInPath().path
    guard resolvedTarget != source.path else { return }
    guard !resolvedTarget.hasPrefix(source.path + "/") else {
      throw ThoughtsError.io("A folder can't move into itself")
    }
    let foreign = try Self.foreignNames(in: source)
    guard foreign.isEmpty else { throw ThoughtsError.folderNotEmpty(foreign) }
    try checkDestination(target)

    switch rename(source, target) {
    case 0:
      try commitRename(from: source, to: target)
    case EXDEV:
      try commitCopy(from: source, to: target)
    case let code:
      throw ThoughtsError.io(String(cString: strerror(code)))
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

  private func commitCopy(from source: URL, to target: URL) throws {
    let fileManager = FileManager.default
    let createdTarget = !fileManager.fileExists(atPath: target.path)
    var copied: [String] = []
    do {
      try Self.createFolder(target)
      for name in try Self.names(in: source) {
        try fileManager.copyItem(
          at: source.appendingPathComponent(name), to: target.appendingPathComponent(name))
        copied.append(name)
      }
      try Self.verifyCopy(of: source, in: target)
      try writeSettings(folder: target)
    } catch {
      if createdTarget {
        try? fileManager.removeItem(at: target)
      } else {
        for name in copied { try? fileManager.removeItem(at: target.appendingPathComponent(name)) }
      }
      throw error
    }
    do {
      try fileManager.removeItem(at: source)
      try fileManager.createSymbolicLink(at: source, withDestinationURL: target)
    } catch {
      throw ThoughtsError.io(
        "Your thoughts are now in \(target.path), but the old folder could not be cleaned up: \(error.localizedDescription)"
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

  private static func verifyCopy(of source: URL, in target: URL) throws {
    let fileManager = FileManager.default
    for name in try names(in: source) {
      let original = try? fileManager.attributesOfItem(
        atPath: source.appendingPathComponent(name).path)
      let copy = try? fileManager.attributesOfItem(
        atPath: target.appendingPathComponent(name).path)
      guard let copy, copy[.size] as? Int == original?[.size] as? Int else {
        throw ThoughtsError.io("The copy of \(name) does not match the original")
      }
    }
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

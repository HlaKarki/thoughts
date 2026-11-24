import ArgumentParser
import Darwin
import Foundation
import ThoughtsCore

public struct CommandEnvironment: Sendable {
  public var location: StorageLocation
  public var indexURL: URL
  public var recognizer: (any TextRecognizing)?
  public var stdin: @Sendable () -> String?
  public var out: @Sendable (String) -> Void
  public var err: @Sendable (String) -> Void
  public var version: String

  public init(
    location: StorageLocation,
    indexURL: URL,
    recognizer: (any TextRecognizing)?,
    stdin: @escaping @Sendable () -> String?,
    out: @escaping @Sendable (String) -> Void,
    err: @escaping @Sendable (String) -> Void,
    version: String = "dev"
  ) {
    self.location = location
    self.indexURL = indexURL
    self.recognizer = recognizer
    self.stdin = stdin
    self.out = out
    self.err = err
    self.version = version
  }

  public static func live() throws -> CommandEnvironment {
    let location = StorageLocation(appName: appName(forExecutable: executable))
    return CommandEnvironment(
      location: location,
      indexURL: location.indexURL,
      recognizer: VisionTextRecognizer(),
      stdin: {
        guard isatty(STDIN_FILENO) == 0 else { return nil }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
      },
      out: { print($0) },
      err: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) },
      version: appVersion(forExecutable: executable)
    )
  }

  static var executable: URL {
    Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
  }

  static func appName(forExecutable executable: URL) -> String {
    guard let name = appInfo(forExecutable: executable)?["CFBundleName"] as? String, !name.isEmpty
    else { return "Thoughts" }
    return name
  }

  static func appVersion(forExecutable executable: URL) -> String {
    guard
      let version = appInfo(forExecutable: executable)?["CFBundleShortVersionString"] as? String,
      !version.isEmpty
    else { return "dev" }
    return version
  }

  private static func appInfo(forExecutable executable: URL) -> [String: Any]? {
    let resolved = executable.resolvingSymlinksInPath()
    let helpers = resolved.deletingLastPathComponent()
    let contents = helpers.deletingLastPathComponent()
    let bundle = contents.deletingLastPathComponent()
    guard helpers.lastPathComponent == "Helpers", contents.lastPathComponent == "Contents",
      bundle.pathExtension == "app",
      let data = try? Data(contentsOf: contents.appendingPathComponent("Info.plist"))
    else { return nil }
    return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
  }
}

protocol EnvironmentCommand: AsyncParsableCommand {
  func execute(in environment: CommandEnvironment) async throws
}

extension EnvironmentCommand {
  func run() async throws {
    try await perform(in: try CommandEnvironment.live())
  }

  func perform(in environment: CommandEnvironment) async throws {
    do {
      try await execute(in: environment)
    } catch {
      environment.err(errorMessage(for: error))
      throw ExitCode(ThoughtsCommands.exitCode(for: error))
    }
  }
}

extension CommandEnvironment {
  func open(recognizer: (any TextRecognizing)? = nil) throws -> (
    store: ThoughtStore, index: SearchIndex, sync: IndexSync
  ) {
    let folder = try location.resolve()
    let store = ThoughtStore(folder: folder)
    let index = try SearchIndex(url: indexURL, folder: folder)
    return (store, index, IndexSync(store: store, index: index, recognizer: recognizer))
  }
}

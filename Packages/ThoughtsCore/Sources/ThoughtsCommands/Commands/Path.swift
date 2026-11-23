import ArgumentParser
import ThoughtsCore

struct PathCommand: EnvironmentCommand {
  static let configuration = CommandConfiguration(
    commandName: "path", abstract: "Print the file path of a thought, or of its image.")

  @Argument(help: "A thought ID, or the first 4 or more characters of one.") var id: String

  func execute(in environment: CommandEnvironment) async throws {
    let store = ThoughtStore(folder: try environment.location.resolve())
    let thought = try store.thought(matching: id)
    environment.out(CopyFormat.path(of: thought, store: store).path)
  }
}

import ArgumentParser
import ThoughtsCore

struct ShowCommand: EnvironmentCommand {
  static let configuration = CommandConfiguration(
    commandName: "show", abstract: "Show one thought.")

  @Argument(help: "A thought ID, or the first 4 or more characters of one.") var id: String
  @Flag(help: "Print JSON.") var json = false

  func execute(in environment: CommandEnvironment) async throws {
    let (thought, store) = try Self.load(matching: id, in: environment)
    environment.out(
      json
        ? try Output.json(ThoughtRecord(thought, store: store))
        : Output.detail(thought, store: store))
  }

  static func load(
    matching id: String, in environment: CommandEnvironment
  ) throws -> (Thought, ThoughtStore) {
    let (store, _, sync) = try environment.open()
    _ = try sync.reconcile(nil)
    return (try store.thought(matching: id), store)
  }
}

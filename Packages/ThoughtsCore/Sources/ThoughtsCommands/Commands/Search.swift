import ArgumentParser
import ThoughtsCore

struct SearchCommand: EnvironmentCommand {
  static let configuration = CommandConfiguration(
    commandName: "search", abstract: "Search thoughts, including text in screenshots.")

  @Argument(help: "The words to look for.") var query: [String]
  @Flag(help: "Print JSON.") var json = false

  func execute(in environment: CommandEnvironment) async throws {
    let (store, index, sync) = try environment.open(recognizer: environment.recognizer)
    _ = try sync.reconcile(nil)
    var byID: [ThoughtID: Thought] = [:]
    for case .thought(let thought) in try index.entries(includeCleared: true) {
      byID[thought.id] = thought
    }
    let found = try index.search(query.joined(separator: " ")).compactMap { byID[$0] }
    if json {
      environment.out(try Output.json(found.map { ThoughtRecord($0, store: store) }))
    } else {
      for thought in found { environment.out(Output.row(thought)) }
    }
  }
}

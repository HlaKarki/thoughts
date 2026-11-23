import ArgumentParser
import ThoughtsCore

struct ListCommand: EnvironmentCommand {
  static let configuration = CommandConfiguration(
    commandName: "list", abstract: "List thoughts, open ones by default.")

  @Flag(help: "Show thoughts that are not done.") var open = false
  @Flag(help: "Show thoughts that are done.") var done = false
  @Flag(help: "Show every thought.") var all = false
  @Flag(help: "Print JSON.") var json = false

  func validate() throws {
    guard [open, done, all].filter({ $0 }).count <= 1 else {
      throw ValidationError("Pass only one of --open, --done and --all")
    }
  }

  func execute(in environment: CommandEnvironment) async throws {
    let (thoughts, store) = try Self.thoughts(
      state: all ? .all : done ? .done : .open, in: environment)
    if json {
      environment.out(try Output.json(thoughts.map { ThoughtRecord($0, store: store) }))
    } else {
      for thought in thoughts { environment.out(Output.row(thought)) }
    }
  }

  static func thoughts(
    state: ListState, in environment: CommandEnvironment
  ) throws -> ([Thought], ThoughtStore) {
    let (store, index, sync) = try environment.open()
    _ = try sync.reconcile(nil)
    let thoughts = try index.entries(includeCleared: state == .all).compactMap {
      entry -> Thought? in
      guard case .thought(let thought) = entry else { return nil }
      switch state {
      case .all: return thought
      case .done: return thought.done == nil ? nil : thought
      case .open: return thought.done == nil ? thought : nil
      }
    }
    return (thoughts, store)
  }
}

enum ListState: String {
  case open
  case done
  case all
}

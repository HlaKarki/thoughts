import ArgumentParser
import Foundation
import ThoughtsCore

struct DoneCommand: EnvironmentCommand {
  static let configuration = CommandConfiguration(
    commandName: "done", abstract: "Mark a thought done, or open again with --undo.")

  @Argument(help: "A thought ID, or the first 4 or more characters of one.") var id: String
  @Flag(help: "Mark the thought open again.") var undo = false
  @Flag(help: "Print JSON.") var json = false

  func execute(in environment: CommandEnvironment) async throws {
    let store = ThoughtStore(folder: try environment.location.resolve())
    var thought = try store.thought(matching: id)
    if (thought.done != nil) == undo {
      thought = try store.setDone(!undo, for: thought.id, at: Date())
    }
    environment.out(
      json ? try Output.json(ThoughtRecord(thought, store: store)) : thought.id.rawValue)
  }
}

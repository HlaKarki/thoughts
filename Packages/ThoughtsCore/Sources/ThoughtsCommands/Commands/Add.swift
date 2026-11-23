import ArgumentParser
import Foundation
import ThoughtsCore

struct AddCommand: EnvironmentCommand {
  static let configuration = CommandConfiguration(
    commandName: "add", abstract: "Add a thought from text, an image or stdin.")

  @Argument(help: "The text of the thought.") var text: [String] = []
  @Option(help: "Add an image file as a screenshot thought.") var image: String?
  @Option(help: "A note for the image.") var note: String?
  @Flag(help: "Print JSON.") var json = false

  func execute(in environment: CommandEnvironment) async throws {
    let source = Source(app: "thoughts CLI")
    var new: NewThought
    if let image {
      guard text.isEmpty else {
        throw ValidationError("Pass text or --image, not both")
      }
      let url = URL(fileURLWithPath: image)
      new = NewThought.fromFile(url, source: source, created: Date())
      guard case .image(let input, _) = new.content else {
        throw ValidationError("\(image) is not an image")
      }
      new.content = .image(input, note: note ?? "")
    } else {
      guard note == nil else { throw ValidationError("--note needs --image") }
      let body = text.isEmpty ? environment.stdin() ?? "" : text.joined(separator: " ")
      let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else {
        throw ValidationError("Pass text or --image, or pipe text in")
      }
      new = NewThought(content: .text(trimmed), source: source)
    }
    let folder = try environment.location.resolve()
    let store = ThoughtStore(folder: folder)
    let thought = try store.add(new)
    environment.out(
      json ? try Output.json(ThoughtRecord(thought, store: store)) : thought.id.rawValue)
  }
}

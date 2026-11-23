import ArgumentParser
import Foundation
import MCP
import ThoughtsCore

public struct ThoughtsMCPServer: Sendable {
  private let environment: CommandEnvironment

  public init(environment: CommandEnvironment) {
    var guarded = environment
    guarded.stdin = { nil }
    guarded.out = environment.err
    self.environment = guarded
  }

  public func tools() -> [Tool] {
    let idSchema: Value = [
      "type": "string",
      "description": "A thought ID, or the first 4 or more characters of one.",
    ]
    return [
      Tool(
        name: "list_thoughts",
        description: "List thoughts, open ones by default.",
        inputSchema: [
          "type": "object",
          "properties": [
            "state": [
              "type": "string",
              "enum": ["open", "done", "all"],
              "description": "Which thoughts to list. Defaults to open.",
            ]
          ],
        ],
        annotations: Tool.Annotations(readOnlyHint: true)
      ),
      Tool(
        name: "add_thought",
        description: "Add a thought from text, or a screenshot thought from an image file.",
        inputSchema: [
          "type": "object",
          "properties": [
            "text": ["type": "string", "description": "The text of the thought."],
            "image_path": ["type": "string", "description": "Path of an image file to add."],
            "note": ["type": "string", "description": "A note for the image. Needs image_path."],
          ],
        ]
      ),
      Tool(
        name: "show_thought",
        description: "Show one thought.",
        inputSchema: [
          "type": "object", "properties": ["id": idSchema], "required": ["id"],
        ],
        annotations: Tool.Annotations(readOnlyHint: true)
      ),
      Tool(
        name: "thought_path",
        description: "Get the file path of a thought, or of its image.",
        inputSchema: [
          "type": "object", "properties": ["id": idSchema], "required": ["id"],
        ],
        annotations: Tool.Annotations(readOnlyHint: true)
      ),
      Tool(
        name: "mark_done",
        description: "Mark a thought done, or open again with done set to false.",
        inputSchema: [
          "type": "object",
          "properties": [
            "id": idSchema,
            "done": [
              "type": "boolean",
              "description": "True to mark done, false to open again. Defaults to true.",
            ],
          ],
          "required": ["id"],
        ]
      ),
      Tool(
        name: "search_thoughts",
        description: "Search thoughts, including text in screenshots.",
        inputSchema: [
          "type": "object",
          "properties": ["query": ["type": "string", "description": "The words to look for."]],
          "required": ["query"],
        ],
        annotations: Tool.Annotations(readOnlyHint: true)
      ),
    ]
  }

  public func call(
    _ name: String, arguments: [String: Value], clientName: String?
  ) async -> CallTool.Result {
    do {
      let text = try perform(name, arguments: Arguments(values: arguments), clientName: clientName)
      return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)])
    } catch {
      return CallTool.Result(
        content: [.text(text: errorMessage(for: error), annotations: nil, _meta: nil)],
        isError: true)
    }
  }

  public func run(transport: any Transport = StdioTransport()) async throws {
    let server = Server(
      name: "thoughts", version: "0.1.0", capabilities: .init(tools: .init(listChanged: false)))
    let client = ClientName()
    let tools = tools()
    await server.withMethodHandler(ListTools.self) { _ in ListTools.Result(tools: tools) }
    await server.withMethodHandler(CallTool.self) { parameters in
      await self.call(
        parameters.name, arguments: parameters.arguments ?? [:], clientName: client.value)
    }
    try await server.start(transport: await DrainingTransport.wrapping(transport)) { info, _ in
      client.value = info.name
    }
    await server.waitUntilCompleted()
    await server.stop()
  }

  private func perform(_ name: String, arguments: Arguments, clientName: String?) throws -> String {
    switch name {
    case "list_thoughts":
      let state = try arguments.optionalString("state") ?? ListState.open.rawValue
      guard let state = ListState(rawValue: state) else {
        throw ValidationError("state must be open, done or all")
      }
      let (thoughts, store) = try ListCommand.thoughts(state: state, in: environment)
      return try Output.json(thoughts.map { ThoughtRecord($0, store: store) }, pretty: false)
    case "add_thought":
      let (thought, store) = try AddCommand.add(
        text: try arguments.optionalString("text"),
        image: try arguments.optionalString("image_path"),
        note: try arguments.optionalString("note"),
        source: Source(app: clientName ?? "MCP"),
        in: environment)
      return try Output.json(ThoughtRecord(thought, store: store), pretty: false)
    case "show_thought":
      let (thought, store) = try ShowCommand.load(
        matching: try arguments.requiredString("id"), in: environment)
      return try Output.json(ThoughtRecord(thought, store: store), pretty: false)
    case "thought_path":
      let path = try PathCommand.path(
        matching: try arguments.requiredString("id"), in: environment)
      return try Output.json(["path": path], pretty: false)
    case "mark_done":
      let (thought, store) = try DoneCommand.mark(
        matching: try arguments.requiredString("id"),
        done: try arguments.optionalBool("done") ?? true,
        in: environment)
      return try Output.json(ThoughtRecord(thought, store: store), pretty: false)
    case "search_thoughts":
      let (found, store) = try SearchCommand.find(
        try arguments.requiredString("query"), in: environment)
      return try Output.json(found.map { ThoughtRecord($0, store: store) }, pretty: false)
    default:
      throw ValidationError("Unknown tool \(name)")
    }
  }
}

private struct Arguments {
  let values: [String: Value]

  func requiredString(_ key: String) throws -> String {
    guard let value = try optionalString(key) else {
      throw ValidationError("Missing argument \(key)")
    }
    return value
  }

  func optionalString(_ key: String) throws -> String? {
    guard let value = values[key], !value.isNull else { return nil }
    guard let string = value.stringValue else {
      throw ValidationError("Argument \(key) must be a string")
    }
    return string
  }

  func optionalBool(_ key: String) throws -> Bool? {
    guard let value = values[key], !value.isNull else { return nil }
    guard let bool = value.boolValue else {
      throw ValidationError("Argument \(key) must be true or false")
    }
    return bool
  }
}

private final class ClientName: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: String?

  var value: String? {
    get { lock.withLock { stored } }
    set { lock.withLock { stored = newValue } }
  }
}

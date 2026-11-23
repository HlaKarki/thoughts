import Foundation
import MCP
import Synchronization
import Testing
import ThoughtsCore

@testable import ThoughtsCommands

private final class QuietRecognizer: TextRecognizing, Sendable {
  func text(in image: URL) throws -> String { "" }
}

private final class Sink: Sendable {
  private let lines = Mutex<[String]>([])

  var all: [String] { lines.withLock { $0 } }

  func add(_ line: String) {
    lines.withLock { $0.append(line) }
  }
}

private final class MCPScratch {
  let root: URL
  let out = Sink()
  let err = Sink()

  init() {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("mcp-tests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(
      at: root.appendingPathComponent("Thoughts"), withIntermediateDirectories: true)
  }

  deinit {
    try? FileManager.default.removeItem(at: root)
  }

  var server: ThoughtsMCPServer {
    let location = StorageLocation(
      environment: ["THOUGHTS_DIR": root.appendingPathComponent("Thoughts").path], home: root)
    return ThoughtsMCPServer(
      environment: CommandEnvironment(
        location: location,
        indexURL: location.indexURL,
        recognizer: QuietRecognizer(),
        stdin: { "unread stdin" },
        out: { [out] in out.add($0) },
        err: { [err] in err.add($0) }
      ))
  }

  @discardableResult
  func call(
    _ name: String, _ arguments: [String: Value] = [:], client: String? = "Test Client"
  ) async -> CallTool.Result {
    await server.call(name, arguments: arguments, clientName: client)
  }
}

private func text(of result: CallTool.Result) -> String {
  guard case .text(let text, _, _)? = result.content.first else { return "" }
  return text
}

private func decoder() -> JSONDecoder {
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  return decoder
}

private func record(_ result: CallTool.Result) throws -> ThoughtRecord {
  try decoder().decode(ThoughtRecord.self, from: Data(text(of: result).utf8))
}

private func records(_ result: CallTool.Result) throws -> [ThoughtRecord] {
  try decoder().decode([ThoughtRecord].self, from: Data(text(of: result).utf8))
}

@Test func offersSixTools() throws {
  let names = MCPScratch().server.tools().map(\.name)
  #expect(
    names == [
      "list_thoughts", "add_thought", "show_thought", "thought_path", "mark_done",
      "search_thoughts",
    ])
}

@Test func addUsesClientNameAsSource() async throws {
  let scratch = MCPScratch()
  let named = await scratch.call("add_thought", ["text": "buy oat milk"])
  #expect(named.isError != true)
  let first = try record(named)
  #expect(first.text == "buy oat milk")
  #expect(first.source?.app == "Test Client")

  let anonymous = await scratch.call("add_thought", ["text": "call the plumber"], client: nil)
  #expect(try record(anonymous).source?.app == "MCP")
}

@Test func markDoneTogglesState() async throws {
  let scratch = MCPScratch()
  let id = try record(await scratch.call("add_thought", ["text": "file taxes"])).id

  let done = try record(await scratch.call("mark_done", ["id": .string(id)]))
  #expect(done.done != nil)
  #expect(try records(await scratch.call("list_thoughts")).isEmpty)
  #expect(try records(await scratch.call("list_thoughts", ["state": "done"])).count == 1)
  #expect(try records(await scratch.call("list_thoughts", ["state": "all"])).count == 1)

  let open = try record(await scratch.call("mark_done", ["id": .string(id), "done": false]))
  #expect(open.done == nil)
  #expect(try records(await scratch.call("list_thoughts")).count == 1)
}

@Test func unknownIDReturnsToolError() async throws {
  let scratch = MCPScratch()
  await scratch.call("add_thought", ["text": "something"])
  for tool in ["show_thought", "thought_path", "mark_done"] {
    let result = await scratch.call(tool, ["id": "zzzzzzzz"])
    #expect(result.isError == true)
    #expect(text(of: result).contains("zzzzzzzz"))
  }
}

@Test func missingOrWrongArgumentsReturnToolErrors() async throws {
  let scratch = MCPScratch()
  let missing = await scratch.call("show_thought")
  #expect(missing.isError == true)
  #expect(text(of: missing).contains("id"))
  #expect(!text(of: missing).contains("\n"))

  #expect(await scratch.call("show_thought", ["id": 5]).isError == true)
  #expect(await scratch.call("search_thoughts").isError == true)
  #expect(await scratch.call("list_thoughts", ["state": "later"]).isError == true)
  #expect(await scratch.call("add_thought", ["text": true]).isError == true)
  #expect(await scratch.call("add_thought").isError == true)
  #expect(await scratch.call("add_thought", ["note": "orphan"]).isError == true)
  #expect(await scratch.call("mark_done", ["id": "abcd", "done": "yes"]).isError == true)

  let unknown = await scratch.call("delete_everything")
  #expect(unknown.isError == true)
  #expect(text(of: unknown).contains("delete_everything"))
}

@Test func readToolsReturnTheThought() async throws {
  let scratch = MCPScratch()
  let added = try record(await scratch.call("add_thought", ["text": "remember the invoice"]))

  let shown = try record(await scratch.call("show_thought", ["id": .string(added.id)]))
  #expect(shown == added)

  let found = try records(await scratch.call("search_thoughts", ["query": "invoice"]))
  #expect(found.map(\.id) == [added.id])
  #expect(try records(await scratch.call("search_thoughts", ["query": "absent"])).isEmpty)

  let path = await scratch.call("thought_path", ["id": .string(added.id)])
  let object = try JSONDecoder().decode([String: String].self, from: Data(text(of: path).utf8))
  #expect(object["path"] == added.file)
}

@Test func toolsNeverWriteToOutOrReadStdin() async throws {
  let scratch = MCPScratch()
  let id = try record(await scratch.call("add_thought", ["text": "quiet"])).id
  await scratch.call("list_thoughts", ["state": "all"])
  await scratch.call("show_thought", ["id": .string(id)])
  await scratch.call("search_thoughts", ["query": "quiet"])
  let empty = await scratch.call("add_thought", ["text": ""])
  #expect(empty.isError == true)
  #expect(scratch.out.all.isEmpty)
}

import ArgumentParser
import Foundation

struct MCPCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mcp", abstract: "Serve thoughts over MCP on standard input and output.")

  func run() async throws {
    do {
      try await ThoughtsMCPServer(environment: try CommandEnvironment.live()).run()
    } catch {
      FileHandle.standardError.write(Data((errorMessage(for: error) + "\n").utf8))
      throw ExitCode(ThoughtsCommands.exitCode(for: error))
    }
  }
}

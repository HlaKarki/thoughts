import ArgumentParser

public struct ThoughtsCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(commandName: "thoughts")

  public init() {}

  public func run() async throws {}
}

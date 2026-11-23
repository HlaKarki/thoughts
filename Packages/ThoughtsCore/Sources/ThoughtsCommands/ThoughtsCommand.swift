import ArgumentParser

public struct ThoughtsCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "thoughts",
    abstract: "Add and read thoughts.",
    subcommands: [
      ListCommand.self, AddCommand.self, ShowCommand.self, PathCommand.self, DoneCommand.self,
      SearchCommand.self,
    ]
  )

  public init() {}
}

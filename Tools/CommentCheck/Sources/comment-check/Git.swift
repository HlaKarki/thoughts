import Foundation

enum Git {
  struct Failure: Error {
    let status: Int32
  }

  @discardableResult
  static func run(_ arguments: [String], in directory: URL) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.currentDirectoryURL = directory
    let output = Pipe()
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw Failure(status: process.terminationStatus)
    }
    return data
  }

  static func listedFiles(in root: URL) throws -> [String] {
    let data = try run(["ls-files", "-z", "--cached", "--others", "--exclude-standard"], in: root)
    return data.split(separator: 0).compactMap { String(data: Data($0), encoding: .utf8) }
  }
}

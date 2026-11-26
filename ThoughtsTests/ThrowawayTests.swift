import AppKit
import Testing

struct ThrowawayTests {
  @Test func aThrowawayLeavesNoDomainAndNoPlistFile() async throws {
    let scope = Throwaway()
    let (name, defaults) = try Throwaway.$current.withValue(scope) { try Throwaway.suite() }
    defaults.set("kept", forKey: "probe")
    defaults.synchronize()
    #expect(FileManager.default.fileExists(atPath: name + ".plist"))
    scope.throwAway()
    try await Task.sleep(for: .milliseconds(500))
    #expect(UserDefaults(suiteName: name)?.persistentDomain(forName: name)?["probe"] == nil)
    #expect(!FileManager.default.fileExists(atPath: scope.folder.path))
    #expect(!name.hasPrefix(NSHomeDirectory() + "/Library/Preferences"))
  }

  @Test func aThrowawayReleasesItsPasteboards() throws {
    let scope = Throwaway()
    let board = Throwaway.$current.withValue(scope) { Throwaway.pasteboard() }
    board.clearContents()
    board.setString("kept", forType: .string)
    scope.throwAway()
    #expect(NSPasteboard(name: board.name).string(forType: .string) == nil)
    NSPasteboard(name: board.name).releaseGlobally()
  }
}

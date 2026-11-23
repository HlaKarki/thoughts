import Foundation
import Testing

@testable import Thoughts

struct ScreenshotLocationTests {
  static let home = URL(fileURLWithPath: "/example/home", isDirectory: true)

  static func defaults(location: String?) throws -> UserDefaults {
    let name = "thoughts.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    if let location { defaults.set(location, forKey: ScreenshotLocation.key) }
    return defaults
  }

  @Test func readsTheConfiguredFolder() throws {
    let location = ScreenshotLocation(
      defaults: try Self.defaults(location: "/Volumes/Work/Shots"), home: Self.home,
      isFolder: { _ in true })
    #expect(location.folder.path == "/Volumes/Work/Shots")
  }

  @Test func expandsTheTilde() throws {
    let location = ScreenshotLocation(
      defaults: try Self.defaults(location: "~/Pictures/Screenshots"), home: Self.home,
      isFolder: { _ in true })
    #expect(location.folder.path == "/example/home/Pictures/Screenshots")
  }

  @Test func fallsBackToTheDesktopWhenNothingIsSet() throws {
    let location = ScreenshotLocation(
      defaults: try Self.defaults(location: nil), home: Self.home, isFolder: { _ in true })
    #expect(location.folder.path == "/example/home/Desktop")
  }

  @Test func fallsBackToTheDesktopWhenTheFolderIsGone() throws {
    let location = ScreenshotLocation(
      defaults: try Self.defaults(location: "~/Missing"), home: Self.home, isFolder: { _ in false })
    #expect(location.folder.path == "/example/home/Desktop")
  }
}

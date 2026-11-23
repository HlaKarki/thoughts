import AppKit
import Sparkle
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
struct UpdateMenuTests {
  static let size = CGSize(width: 32, height: 32)

  static func button(
    updateAvailable: Bool, appearance: NSAppearance.Name = .aqua, name: String
  ) throws -> URL {
    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let updates = UpdateMenuItem()
    if updateAvailable { updates.updateWillShow(handledBySparkle: false) }
    let shared = SharedMenuItems(updates: updates, openSettings: {}, checkForUpdates: {})
    return try SnapshotRenderer.render(
      MoreMenu(preferences: Preferences(defaults: defaults), shared: shared),
      size: Self.size, appearance: appearance, name: name)
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func moreButtonWithUpdateDot(_ appearance: NSAppearance.Name) throws {
    let url = try Self.button(
      updateAvailable: true, appearance: appearance,
      name: "more-button-update-\(appearance == .aqua ? "light" : "dark")")
    let image = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
    #expect(image.pixelsWide == Int(Self.size.width) * SnapshotRenderer.scale)
    #expect(image.pixelsHigh == Int(Self.size.height) * SnapshotRenderer.scale)
    #expect(SnapshotTests.colorCount(of: image) > 1)
  }

  @Test func foundUpdateShowsTheItemAndTheDotUntilTheSessionEnds() throws {
    let updater = Updater(starting: false)
    let item = updater.item
    #expect(updater.supportsGentleScheduledUpdateReminders)
    #expect(
      !updater.standardUserDriverShouldHandleShowingScheduledUpdate(
        .empty(), andInImmediateFocus: true))
    let plain = try Data(contentsOf: Self.button(updateAvailable: false, name: "more-button-plain"))

    item.updateWillShow(handledBySparkle: true)
    #expect(!item.isShown)
    item.updateWillShow(handledBySparkle: false)
    #expect(item.isShown)
    let found = try Data(
      contentsOf: Self.button(updateAvailable: item.isShown, name: "more-button-found"))
    #expect(found != plain)

    updater.standardUserDriverWillFinishUpdateSession()
    #expect(!item.isShown)
    let ended = try Data(
      contentsOf: Self.button(updateAvailable: item.isShown, name: "more-button-ended"))
    #expect(ended == plain)
  }
}

import AppKit
import Foundation
import OSLog
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
@Suite(.serialized, .throwaway)
struct CaptureLogTests {
  typealias Rig = EngineCopyCaptureTests.Rig

  static func line(for trail: CaptureTrail) -> String {
    "shift twice probe=\(trail.probeName) secureInput=\(trail.secureInput) "
      + "secureFocus=\(trail.secureFocus) fallback=\(trail.fallbackRan) "
      + "copy=\(trail.copyKind) age=\(trail.copyAge) own=\(trail.copyOwn) "
      + "polled=\(trail.polled) current=\(trail.currentCount) action=\(trail.actionName)"
  }

  static func captureLines(since start: Date, expecting line: String) async throws -> [String] {
    var lines: [String] = []
    for _ in 0..<40 {
      let store = try OSLogStore(scope: .currentProcessIdentifier)
      let predicate = NSPredicate(
        format: "subsystem == %@ AND category == %@", CaptureLog.subsystem, CaptureLog.category)
      lines = try store.getEntries(at: store.position(date: start), matching: predicate)
        .compactMap { ($0 as? OSLogEntryLog)?.composedMessage }
      if lines.contains(line) { return lines }
      try await Task.sleep(for: .milliseconds(50))
    }
    return lines
  }

  @Test func aCopyTheWatcherWasBehindOnLogsBothCountsTheFallbackAndTheSave() async throws {
    let rig = try Rig()
    defer { rig.close() }
    let before = rig.board.changeCount
    rig.copy(.writeText)
    rig.reader.probeResult = .unavailable
    rig.reader.copyResult = .copiedNothing
    _ = await rig.coordinator.capture()
    let trail = try #require(rig.trails.all.last)
    #expect(trail.probeName == "unavailable")
    #expect(!trail.secureInput)
    #expect(!trail.secureFocus)
    #expect(trail.fallbackRan)
    #expect(trail.copyKind == "text")
    #expect(trail.copyAge == "0")
    #expect(trail.copyOwn == "false")
    #expect(trail.polledCount == before)
    #expect(trail.currentCount == rig.board.changeCount)
    #expect(trail.polledCount != trail.currentCount)
    #expect(trail.actionName == "saveCopiedText")
  }

  @Test func theFrontAppsPasswordFieldLogsASecureFocusAndNoFallback() async throws {
    let rig = try Rig(captureDelay: 7)
    defer { rig.close() }
    rig.copy(.writeText)
    await rig.poll()
    rig.reader.secureInputOn = true
    rig.reader.probeResult = .secureField
    #expect(await rig.coordinator.capture() == .nothingToSave)
    let trail = try #require(rig.trails.all.last)
    #expect(trail.probeName == "secureField")
    #expect(trail.secureInput)
    #expect(trail.secureFocus)
    #expect(!trail.fallbackRan)
    #expect(trail.copyKind == "text")
    #expect(trail.copyAge == "7")
    #expect(trail.polledCount == trail.currentCount)
    #expect(trail.actionName == "nothingToSave")
  }

  @Test func aShiftTwiceWhileAThoughtsWindowIsKeyLogsTheProbeAsSkipped() async throws {
    let rig = try Rig()
    defer { rig.close() }
    rig.keys.becomeKey(rig.panel)
    #expect(await rig.coordinator.capture() == .nothingToSave)
    let trail = try #require(rig.trails.all.last)
    #expect(trail.probeName == "skipped")
    #expect(trail.copyKind == "none")
    #expect(trail.copyAge == "none")
    #expect(trail.copyOwn == "none")
    #expect(trail.actionName == "nothingToSave")
    #expect(rig.reader.probed.isEmpty)
  }

  @Test func theLogLineShowsEveryFactInTheClearAndNeverTheCopiedTextOrPage() async throws {
    let start = Date()
    let rig = try Rig()
    defer { rig.close() }
    rig.copy(.selection)
    rig.reader.probeResult = .unavailable
    rig.reader.copyResult = .copiedNothing
    _ = await rig.coordinator.capture()
    #expect(try rig.storedTexts == [EngineCopyCaptureTests.words])
    let trail = try #require(rig.trails.all.last)
    let line = Self.line(for: trail)
    let lines = try await Self.captureLines(since: start, expecting: line)
    #expect(lines.contains(line), "got \(lines)")
    let appName = try #require(EngineCopyCaptureTests.browser.name)
    for logged in lines {
      #expect(!logged.contains(EngineCopyCaptureTests.words))
      #expect(!logged.contains("example.com"))
      #expect(!logged.contains(appName))
      #expect(!logged.contains("<private>"))
    }
  }
}

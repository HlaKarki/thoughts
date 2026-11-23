import Foundation
import Sparkle
import Testing

@testable import Thoughts

@MainActor
final class SilentUserDriver: NSObject, SPUUserDriver {
  func show(_ request: SPUUpdatePermissionRequest) async -> SUUpdatePermissionResponse {
    SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false)
  }
  func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}
  func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState) async
    -> SPUUserUpdateChoice
  { .dismiss }
  func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
  func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}
  func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
    acknowledgement()
  }
  func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
    acknowledgement()
  }
  func showDownloadInitiated(cancellation: @escaping () -> Void) {}
  func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
  func showDownloadDidReceiveData(ofLength length: UInt64) {}
  func showDownloadDidStartExtractingUpdate() {}
  func showExtractionReceivedProgress(_ progress: Double) {}
  func showReady(toInstallAndRelaunch: @escaping (SPUUserUpdateChoice) -> Void) {
    toInstallAndRelaunch(.dismiss)
  }
  func showInstallingUpdate(
    withApplicationTerminated applicationTerminated: Bool,
    retryTerminatingApplication: @escaping () -> Void
  ) {}
  func showUpdateInstalledAndRelaunched(
    _ relaunched: Bool, acknowledgement: @escaping () -> Void
  ) {
    acknowledgement()
  }
  func dismissUpdateInstallation() {}
}

@MainActor
final class RefusingUpdaterDelegate: NSObject, SPUUpdaterDelegate {
  func updater(
    _ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck
  ) throws {
    throw CocoaError(.userCancelled)
  }
}

@MainActor
struct UpdaterStartTests {
  @Test func theUpdaterStartsWithTheAppsOwnInfoPlist() async throws {
    let defaults = UserDefaults.standard
    let hadLaunched = defaults.object(forKey: "SUHasLaunchedBefore") != nil
    let driver = SilentUserDriver()
    let delegate = RefusingUpdaterDelegate()
    let updater = SPUUpdater(
      hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: delegate)

    try updater.start()
    await withCheckedContinuation { done in DispatchQueue.main.async { done.resume() } }
    if !hadLaunched { defaults.removeObject(forKey: "SUHasLaunchedBefore") }

    #expect(!updater.sessionInProgress)
    #expect(updater.feedURL?.scheme == "https")
    #expect(Bundle.main.object(forInfoDictionaryKey: "SURequireSignedFeed") as? Bool == true)
  }
}

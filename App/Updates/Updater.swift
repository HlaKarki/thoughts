import Sparkle

@MainActor
final class Updater: NSObject {
  let item: UpdateMenuItem
  private var controller: SPUStandardUpdaterController?

  init(item: UpdateMenuItem = UpdateMenuItem(), starting: Bool = true) {
    self.item = item
    super.init()
    controller = SPUStandardUpdaterController(
      startingUpdater: starting, updaterDelegate: nil, userDriverDelegate: self)
  }

  func checkForUpdates() {
    controller?.checkForUpdates(nil)
  }
}

extension Updater: @preconcurrency SPUStandardUserDriverDelegate {
  var supportsGentleScheduledUpdateReminders: Bool { true }

  func standardUserDriverShouldHandleShowingScheduledUpdate(
    _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
  ) -> Bool {
    false
  }

  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
  ) {
    item.updateWillShow(handledBySparkle: handleShowingUpdate)
  }

  func standardUserDriverWillFinishUpdateSession() {
    item.sessionWillFinish()
  }
}

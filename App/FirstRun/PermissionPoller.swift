@MainActor
final class PermissionPoller {
  private let isTrusted: @MainActor () -> Bool
  private let interval: Duration

  init(isTrusted: @escaping @MainActor () -> Bool, interval: Duration = .seconds(1)) {
    self.isTrusted = isTrusted
    self.interval = interval
  }

  func waitForAccessibility() async {
    while !isTrusted() {
      do {
        try await Task.sleep(for: interval)
      } catch {
        return
      }
    }
  }
}

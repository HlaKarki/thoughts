import AppKit
import ApplicationServices

@MainActor
final class AccessibilityTrustWatch: NSObject {
  static let changed = Notification.Name("com.apple.accessibility.api")

  var onGranted: @MainActor () -> Void = {}
  private let isTrusted: @MainActor () -> Bool
  private let center: NotificationCenter
  private let name: Notification.Name
  private let recheckDelay: @Sendable () async throws -> Void
  private var trusted: Bool?
  private var recheck: Task<Void, Never>?

  init(
    isTrusted: @escaping @MainActor () -> Bool = { AXIsProcessTrusted() },
    center: NotificationCenter = DistributedNotificationCenter.default(),
    name: Notification.Name = AccessibilityTrustWatch.changed,
    recheckDelay: @escaping @Sendable () async throws -> Void = {
      try await Task.sleep(for: .seconds(1))
    }
  ) {
    self.isTrusted = isTrusted
    self.center = center
    self.name = name
    self.recheckDelay = recheckDelay
  }

  func start() {
    guard trusted == nil else { return }
    trusted = isTrusted()
    let selector = #selector(trustMayHaveChanged(_:))
    if let distributed = center as? DistributedNotificationCenter {
      distributed.addObserver(
        self, selector: selector, name: name, object: nil, suspensionBehavior: .deliverImmediately)
    } else {
      center.addObserver(self, selector: selector, name: name, object: nil)
    }
  }

  func stop() {
    guard trusted != nil else { return }
    center.removeObserver(self, name: name, object: nil)
    recheck?.cancel()
    recheck = nil
    trusted = nil
  }

  func check() {
    guard let was = trusted else { return }
    let now = isTrusted()
    trusted = now
    if now, !was { onGranted() }
  }

  private func notified() {
    guard trusted != nil else { return }
    check()
    recheck?.cancel()
    recheck = Task { [weak self, recheckDelay] in
      do { try await recheckDelay() } catch { return }
      guard !Task.isCancelled else { return }
      self?.check()
    }
  }

  @objc nonisolated private func trustMayHaveChanged(_ notification: Notification) {
    Task { @MainActor [weak self] in self?.notified() }
  }
}

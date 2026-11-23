import ServiceManagement

enum LoginStatus: Equatable {
  case off
  case on
  case requiresApproval
}

@MainActor
enum LoginItem {
  static var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  static var status: LoginStatus {
    status(for: SMAppService.mainApp.status)
  }

  nonisolated static func status(for service: SMAppService.Status) -> LoginStatus {
    switch service {
    case .enabled: .on
    case .requiresApproval: .requiresApproval
    case .notRegistered, .notFound: .off
    @unknown default: .off
    }
  }

  static func set(_ enabled: Bool) throws {
    let service = SMAppService.mainApp
    let current = status(for: service.status)
    if enabled {
      if current == .off { try service.register() }
    } else if current != .off {
      try service.unregister()
    }
  }

  static func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}

struct LoginControl: Sendable {
  var status: @MainActor () -> LoginStatus
  var set: @MainActor (Bool) throws -> Void
  var openSettings: @MainActor () -> Void

  static let live = LoginControl(
    status: { LoginItem.status },
    set: { try LoginItem.set($0) },
    openSettings: { LoginItem.openSystemSettings() })
}

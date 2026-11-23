import AppKit

enum LaunchKind: Equatable {
  case login
  case manual

  static func current() -> LaunchKind {
    let event = NSAppleEventManager.shared().currentAppleEvent
    let data = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))
    return from(propData: data?.enumCodeValue)
  }

  static func from(propData: OSType?) -> LaunchKind {
    propData == OSType(keyAELaunchedAsLogInItem) ? .login : .manual
  }
}

enum LaunchAction: Equatable {
  case firstRun
  case showPanel
  case nothing

  static func decide(firstRunDone: Bool, kind: LaunchKind) -> LaunchAction {
    guard firstRunDone else { return .firstRun }
    return kind == .login ? .nothing : .showPanel
  }
}

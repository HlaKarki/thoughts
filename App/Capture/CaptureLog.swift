import Foundation
import OSLog
import ThoughtsCore

struct CaptureTrail: Equatable {
  var probe: SelectionProbe?
  var secureInput: Bool
  var fallbackRan = false
  var copy: ClipboardCopy?
  var polledCount: Int?
  var currentCount: Int
  var action: CaptureAction = .nothingToSave
  var now: Date

  var probeName: String {
    switch probe {
    case nil: "skipped"
    case .text: "text"
    case .empty: "empty"
    case .unavailable: "unavailable"
    case .secureField: "secureField"
    case .copiedNothing: "copiedNothing"
    case .copyDisabled: "copyDisabled"
    }
  }

  var secureFocus: Bool { probe == .secureField }

  var copyKind: String {
    switch copy?.kind {
    case nil: "none"
    case .text: "text"
    case .image: "image"
    case .unknown: "unknown"
    }
  }

  var copyAge: String {
    guard let copy else { return "none" }
    return String(Int(now.timeIntervalSince(copy.seen).rounded(.down)))
  }

  var copyOwn: String {
    copy.map { String($0.own) } ?? "none"
  }

  var polled: String {
    polledCount.map(String.init) ?? "none"
  }

  var actionName: String {
    switch action {
    case .acceptOffer: "acceptOffer"
    case .saveText: "saveText"
    case .copyFallback: "copyFallback"
    case .readClipboard: "readClipboard"
    case .saveCopiedText: "saveCopiedText"
    case .saveClipboardImage: "saveClipboardImage"
    case .alreadySaved: "alreadySaved"
    case .clipboardRefused: "clipboardRefused"
    case .nothingToSave: "nothingToSave"
    }
  }
}

enum CaptureLog {
  static let subsystem = Bundle.main.bundleIdentifier ?? "dev.hla.thoughts"
  static let category = "capture"
  static let logger = Logger(subsystem: subsystem, category: category)

  static func record(_ trail: CaptureTrail) {
    logger.notice(
      """
      shift twice probe=\(trail.probeName, privacy: .public) \
      secureInput=\(trail.secureInput, privacy: .public) \
      secureFocus=\(trail.secureFocus, privacy: .public) \
      fallback=\(trail.fallbackRan, privacy: .public) \
      copy=\(trail.copyKind, privacy: .public) \
      age=\(trail.copyAge, privacy: .public) \
      own=\(trail.copyOwn, privacy: .public) \
      polled=\(trail.polled, privacy: .public) \
      current=\(trail.currentCount, privacy: .public) \
      action=\(trail.actionName, privacy: .public)
      """)
  }
}

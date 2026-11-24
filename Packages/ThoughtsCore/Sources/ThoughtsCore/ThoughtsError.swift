import Foundation

public enum ThoughtsError: Error, Equatable, Sendable {
  case storageUnavailable(String)
  case notFound(String)
  case ambiguous(String, [ThoughtID])
  case changedOnDisk(ThoughtID)
  case deletedOnDisk(ThoughtID)
  case folderNotEmpty([String])
  case clipboardChanged
  case io(String)
}

extension ThoughtsError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .storageUnavailable:
      String(localized: "The thoughts folder isn't available. Choose it in Settings.")
    case .notFound:
      String(localized: "That thought isn't there anymore")
    case .ambiguous:
      String(localized: "More than one thought matches")
    case .changedOnDisk:
      String(localized: "That thought changed on disk")
    case .deletedOnDisk:
      String(localized: "That thought was deleted")
    case .folderNotEmpty:
      String(localized: "The folder isn't empty")
    case .clipboardChanged:
      String(localized: "The clipboard changed")
    case .io(let detail):
      detail
    }
  }
}

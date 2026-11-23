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

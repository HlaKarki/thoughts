import ArgumentParser
import ThoughtsCore

public func exitCode(for error: Error) -> Int32 {
  switch error {
  case let error as ThoughtsError:
    switch error {
    case .notFound, .ambiguous: 1
    case .storageUnavailable: 3
    case .changedOnDisk, .deletedOnDisk, .folderNotEmpty, .clipboardChanged, .io: 4
    }
  case is ValidationError: ExitCode.validationFailure.rawValue
  case let error as ExitCode: error.rawValue
  default: 4
  }
}

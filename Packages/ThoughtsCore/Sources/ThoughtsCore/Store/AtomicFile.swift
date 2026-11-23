import Darwin
import Foundation

enum AtomicFileError: Error {
  case exists
  case changed
  case missing
}

struct DiskInfo {
  let version: FileVersion
  let birth: Date
}

enum AtomicFile {
  enum Target {
    case new
    case replacing(FileVersion)
  }

  static func info(at url: URL) throws -> DiskInfo {
    var info = stat()
    guard stat(url.path, &info) == 0 else {
      if errno == ENOENT { throw AtomicFileError.missing }
      throw posixError()
    }
    return DiskInfo(
      version: FileVersion(modified: date(info.st_mtimespec), size: Int(info.st_size)),
      birth: date(info.st_birthtimespec)
    )
  }

  @discardableResult
  static func write(_ data: Data, to url: URL, target: Target) throws -> FileVersion {
    try stage(for: url, target: target) { temp in
      try data.write(to: temp, options: .withoutOverwriting)
    }
  }

  static func stage(
    for url: URL, target: Target, _ fill: (URL) throws -> Void
  ) throws -> FileVersion {
    let temp = url.deletingLastPathComponent()
      .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
    do {
      try fill(temp)
      let handle = try FileHandle(forUpdating: temp)
      try handle.synchronize()
      try handle.close()
      let version = try info(at: temp).version
      try publish(temp, to: url, target: target)
      return version
    } catch {
      try? FileManager.default.removeItem(at: temp)
      throw error
    }
  }

  private static func publish(_ temp: URL, to url: URL, target: Target) throws {
    switch target {
    case .new:
      guard renamex_np(temp.path, url.path, UInt32(RENAME_EXCL)) == 0 else {
        if errno == EEXIST { throw AtomicFileError.exists }
        throw posixError()
      }
    case .replacing(let expected):
      guard try info(at: url).version == expected else { throw AtomicFileError.changed }
      guard rename(temp.path, url.path) == 0 else { throw posixError() }
    }
  }

  private static func posixError() -> ThoughtsError {
    .io(String(cString: strerror(errno)))
  }

  private static func date(_ time: timespec) -> Date {
    Date(timeIntervalSince1970: Double(time.tv_sec) + Double(time.tv_nsec) / 1_000_000_000)
  }
}

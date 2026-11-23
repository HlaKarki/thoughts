import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageWriter {
  static func write(_ input: ImageInput, base: String, in folder: URL) throws -> String {
    switch input {
    case .data(let data, let type):
      let name = base + ".png"
      let destination = folder.appendingPathComponent(name)
      if type == .png {
        try AtomicFile.write(data, to: destination, target: .new)
      } else {
        _ = try AtomicFile.stage(for: destination, target: .new) { temp in
          try convertToPNG(data, at: temp)
        }
      }
      return name
    case .file(let source):
      let ext = source.pathExtension
      guard !ext.isEmpty else { throw ThoughtsError.io("Image file has no extension") }
      let name = base + "." + ext
      _ = try AtomicFile.stage(for: folder.appendingPathComponent(name), target: .new) { temp in
        try copyBytes(from: source, to: temp)
      }
      return name
    }
  }

  private static func copyBytes(from source: URL, to destination: URL) throws {
    let reader = try FileHandle(forReadingFrom: source)
    defer { try? reader.close() }
    guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
      throw ThoughtsError.io("Could not create a temporary image file")
    }
    let writer = try FileHandle(forWritingTo: destination)
    defer { try? writer.close() }
    while let chunk = try reader.read(upToCount: 1 << 20), !chunk.isEmpty {
      try writer.write(contentsOf: chunk)
    }
  }

  private static func convertToPNG(_ data: Data, at url: URL) throws {
    guard
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) > 0,
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw ThoughtsError.io("Image data could not be read") }
    CGImageDestinationAddImageFromSource(destination, source, 0, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw ThoughtsError.io("Image could not be converted to PNG")
    }
  }
}

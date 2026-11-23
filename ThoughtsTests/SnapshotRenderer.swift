import AppKit
import SwiftUI

enum SnapshotRenderer {
  enum Failure: Error {
    case noBitmap
    case noPNG
  }

  static let scale = 2

  @MainActor
  static func render(
    _ view: some View, size: CGSize, appearance: NSAppearance.Name, name: String
  ) throws -> URL {
    let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
    hosting.appearance = NSAppearance(named: appearance)
    hosting.frame = CGRect(origin: .zero, size: size)
    hosting.layoutSubtreeIfNeeded()
    guard
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width) * scale,
        pixelsHigh: Int(size.height) * scale,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0)
    else { throw Failure.noBitmap }
    bitmap.size = size
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
      throw Failure.noPNG
    }
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("ThoughtsSnapshots", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("\(name).png")
    try png.write(to: url)
    return url
  }
}

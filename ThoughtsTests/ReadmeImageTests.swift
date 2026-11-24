import AppKit
import SwiftUI
import Testing
import ThoughtsCore

@testable import Thoughts

@MainActor
struct ReadmeImageTests {
  nonisolated static let outputFolder = ProcessInfo.processInfo.environment[
    "THOUGHTS_README_IMAGES"]
  static let panelSize = CGSize(width: 360, height: 420)
  static let morning = ListFixture.now.addingTimeInterval(4 * 3600)

  @Test(.enabled(if: outputFolder != nil), arguments: [NSAppearance.Name.aqua, .darkAqua])
  func panel(_ appearance: NSAppearance.Name) async throws {
    let output = URL(fileURLWithPath: try #require(Self.outputFolder), isDirectory: true)
    let fixture = try ListFixture()
    defer { withExtendedLifetime(fixture) {} }
    try fixture.addText("Renew the domain before Friday", daysAgo: 2)
    let shot = try fixture.store.add(
      NewThought(
        content: .image(.data(try Self.screenshot(), .png), note: "Tighten the sidebar spacing"),
        created: Self.morning.addingTimeInterval(-21 * 60)))
    try fixture.store.add(
      NewThought(
        content: .text(
          "The import should keep the original file dates, so sorting by created still matches the order people wrote things in."
        ),
        created: Self.morning.addingTimeInterval(-3 * 60)))
    try fixture.reload()
    fixture.model.now = Self.morning
    if case .image(let name, _) = shot.content {
      _ = await ThumbnailLoader.load(fixture.folder.appendingPathComponent(name))
    }

    let defaults = try #require(UserDefaults(suiteName: "thoughts.tests.\(UUID().uuidString)"))
    let suffix = appearance == .aqua ? "light" : "dark"
    let rendered = try SnapshotRenderer.render(
      PanelRootView(
        preferences: Preferences(defaults: defaults), list: fixture.model, input: fixture.input),
      size: Self.panelSize, appearance: appearance, name: "readme-panel-\(suffix)")
    let image = try #require(NSBitmapImageRep(data: Data(contentsOf: rendered)))
    Self.removeFieldEdgeArtifacts(from: image)
    #expect(image.pixelsWide == Int(Self.panelSize.width) * SnapshotRenderer.scale)
    #expect(SnapshotTests.colorCount(of: image) > 1)

    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    try #require(image.representation(using: .png, properties: [:])).write(
      to: output.appendingPathComponent("panel-\(suffix).png"), options: .atomic)
    await ListFixture.settle()
  }

  static func removeFieldEdgeArtifacts(from image: NSBitmapImageRep) {
    let scale = SnapshotRenderer.scale
    let inset = 12 * scale
    let rows = (Int(panelSize.height) - 74) * scale..<(Int(panelSize.height) - 36) * scale
    let leftEdge = inset..<inset + scale
    let rightEdge = image.pixelsWide - inset - scale..<image.pixelsWide - inset
    for y in rows {
      for (edge, source) in [
        (leftEdge, inset - 2 * scale), (rightEdge, image.pixelsWide - inset + 2 * scale - 1),
      ] {
        guard let clean = image.colorAt(x: source, y: y) else { continue }
        for x in edge { image.setColor(clean, atX: x, y: y) }
      }
    }
  }

  static func screenshot() throws -> Data {
    let width = 656
    let height = 416
    let context = try #require(
      CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    func fill(_ gray: CGFloat, _ rect: CGRect, radius: CGFloat = 0) {
      context.setFillColor(CGColor(gray: gray, alpha: 1))
      context.addPath(
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
      context.fillPath()
    }
    fill(0.98, CGRect(x: 0, y: 0, width: width, height: height))
    fill(0.93, CGRect(x: 0, y: 0, width: 168, height: height))
    fill(0.9, CGRect(x: 0, y: height - 44, width: width, height: 44))
    for (index, gray) in [0.82, 0.74, 0.66].enumerated() {
      context.setFillColor(CGColor(gray: gray, alpha: 1))
      context.fillEllipse(in: CGRect(x: 18 + index * 24, y: height - 30, width: 14, height: 14))
    }
    for row in 0..<5 {
      fill(
        row == 1 ? 0.25 : 0.72, CGRect(x: 24, y: height - 92 - row * 34, width: 104, height: 12),
        radius: 6)
    }
    let lines: [(CGFloat, CGFloat)] = [
      (0.55, 300), (0.78, 380), (0.78, 340), (0.78, 400), (0.78, 260),
    ]
    for (row, line) in lines.enumerated() {
      fill(
        line.0, CGRect(x: 208, y: CGFloat(height - 96 - row * 46), width: line.1, height: 14),
        radius: 7)
    }
    context.setStrokeColor(CGColor(red: 1, green: 0.23, blue: 0.19, alpha: 1))
    context.setLineWidth(5)
    context.addPath(
      CGPath(
        roundedRect: CGRect(x: 10, y: height - 140, width: 140, height: 52), cornerWidth: 14,
        cornerHeight: 14, transform: nil))
    context.strokePath()
    let image = try #require(context.makeImage())
    return try #require(
      NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
  }
}

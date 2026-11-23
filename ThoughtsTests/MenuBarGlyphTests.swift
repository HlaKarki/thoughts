import AppKit
import Testing

@testable import Thoughts

@MainActor
struct MenuBarGlyphTests {
  static let cell = CGSize(width: 24, height: 24)
  static let scales = [1, 2]

  static func bitmap(for size: CGSize, scale: Int) throws -> NSBitmapImageRep {
    let rep = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale,
        pixelsHigh: Int(size.height) * scale, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
        bitsPerPixel: 0))
    rep.size = size
    return rep
  }

  static func alphaRow(of glyph: NSImage, scale: Int, row: Int) throws -> [UInt8] {
    let rep = try bitmap(for: MenuBarGlyph.size, scale: scale)
    let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    glyph.draw(in: CGRect(origin: .zero, size: MenuBarGlyph.size))
    NSGraphicsContext.restoreGraphicsState()
    return (0..<rep.pixelsWide).map { column in
      UInt8((rep.colorAt(x: column, y: row)?.alphaComponent ?? 0) * 255)
    }
  }

  final class Backdrop: NSView {
    var tint = NSColor.black
    var fill = NSColor.white
    var updateWaiting = false

    override func draw(_ dirtyRect: NSRect) {
      fill.setFill()
      bounds.fill()
      NSGraphicsContext.saveGraphicsState()
      let transform = NSAffineTransform()
      transform.translateX(
        by: (bounds.width - MenuBarGlyph.size.width) / 2,
        yBy: (bounds.height - MenuBarGlyph.size.height) / 2)
      transform.concat()
      let waiting = updateWaiting
      let color = tint
      let layer = NSImage(size: MenuBarGlyph.size, flipped: false) { _ in
        NSColor.black.setFill()
        MenuBarGlyph.draw(updateWaiting: waiting)
        return true
      }
      let tinted = NSImage(size: MenuBarGlyph.size, flipped: false) { rect in
        layer.draw(in: rect)
        color.setFill()
        rect.fill(using: .sourceIn)
        return true
      }
      tinted.draw(in: CGRect(origin: .zero, size: MenuBarGlyph.size))
      NSGraphicsContext.restoreGraphicsState()
    }
  }

  static func render(
    updateWaiting: Bool, appearance: NSAppearance.Name, scale: Int, name: String
  ) throws -> URL {
    let dark = appearance == .darkAqua
    let backdrop = Backdrop(frame: CGRect(origin: .zero, size: cell))
    backdrop.appearance = NSAppearance(named: appearance)
    backdrop.fill = dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.93, alpha: 1)
    backdrop.tint = dark ? .white : .black
    backdrop.updateWaiting = updateWaiting
    if updateWaiting { MenuBarGlyph.install(dot: UpdateDotView(), in: backdrop) }
    let rep = try bitmap(for: cell, scale: scale)
    backdrop.cacheDisplay(in: backdrop.bounds, to: rep)
    let png = try #require(rep.representation(using: .png, properties: [:]))
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("ThoughtsSnapshots", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("\(name).png")
    try png.write(to: url)
    return url
  }

  @Test(arguments: [1, 2])
  func theCaretAndBarEdgesLandOnWholePixelsSoTheyAreCrisp(scale: Int) throws {
    let glyph = MenuBarGlyph.image(updateWaiting: false)
    let caretHeightRow = scale * 9
    let row = try Self.alphaRow(of: glyph, scale: scale, row: caretHeightRow)
    #expect(Set(row) == [0, 255])
    #expect(row.filter { $0 == 255 }.count == 3 * scale)
    let barRow = try Self.alphaRow(of: glyph, scale: scale, row: scale * 14)
    #expect(barRow[(2 * scale)..<(11 * scale)].allSatisfy { $0 == 255 })
    #expect(barRow[(13 * scale)..<(15 * scale)].allSatisfy { $0 == 0 })
  }

  @Test func theGlyphIsATemplateSoMacOSTintsIt() {
    #expect(MenuBarGlyph.image(updateWaiting: false).isTemplate)
    #expect(MenuBarGlyph.image(updateWaiting: true).isTemplate)
    #expect(MenuBarGlyph.image(updateWaiting: false).size == MenuBarGlyph.size)
  }

  @Test func theUpdateCutoutRemovesInkAroundTheDot() throws {
    let plain = try Self.alphaRow(
      of: MenuBarGlyph.image(updateWaiting: false), scale: 2, row: 2 * 3)
    let cut = try Self.alphaRow(of: MenuBarGlyph.image(updateWaiting: true), scale: 2, row: 2 * 3)
    #expect(plain.reduce(0) { $0 + Int($1) } > cut.reduce(0) { $0 + Int($1) })
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua], [false, true])
  func theIconRendersInLightAndDarkWithAndWithoutTheDot(
    appearance: NSAppearance.Name, updateWaiting: Bool
  ) throws {
    for scale in Self.scales {
      let name =
        "menubar-\(appearance == .aqua ? "light" : "dark")-\(updateWaiting ? "dot" : "plain")-\(scale)x"
      let url = try Self.render(
        updateWaiting: updateWaiting, appearance: appearance, scale: scale, name: name)
      let image = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
      #expect(image.pixelsWide == Int(Self.cell.width) * scale)
      #expect(image.pixelsHigh == Int(Self.cell.height) * scale)
      #expect(SnapshotTests.colorCount(of: image) > 1)
    }
  }

  @Test func theDotChangesThePicture() throws {
    let plain = try Data(
      contentsOf: Self.render(
        updateWaiting: false, appearance: .aqua, scale: 2, name: "menubar-compare-plain"))
    let dotted = try Data(
      contentsOf: Self.render(
        updateWaiting: true, appearance: .aqua, scale: 2, name: "menubar-compare-dot"))
    #expect(plain != dotted)
  }

  @Test func theLabelSaysWhenAnUpdateWaits() {
    #expect(MenuBarGlyph.label(updateWaiting: false) == "Thoughts")
    #expect(MenuBarGlyph.label(updateWaiting: true) == "Thoughts, update available")
  }
}

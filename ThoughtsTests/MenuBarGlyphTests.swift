import AppKit
import Testing

@testable import Thoughts

@MainActor
struct MenuBarGlyphTests {
  static let cell = CGSize(width: MenuBarGlyph.buttonLength, height: 24)

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
    let rep = try bitmap(for: glyph.size, scale: scale)
    let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    glyph.draw(in: CGRect(origin: .zero, size: glyph.size))
    NSGraphicsContext.restoreGraphicsState()
    return (0..<rep.pixelsWide).map { column in
      UInt8((rep.colorAt(x: column, y: row)?.alphaComponent ?? 0) * 255)
    }
  }

  final class Backdrop: NSView {
    var tint = NSColor.black
    var fill = NSColor.white
    var selection: NSColor?

    override func draw(_ dirtyRect: NSRect) {
      fill.setFill()
      bounds.fill()
      if let selection {
        selection.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 1), xRadius: 5, yRadius: 5).fill()
      }
      NSGraphicsContext.saveGraphicsState()
      let transform = NSAffineTransform()
      let size = MenuBarGlyph.canvas
      transform.translateX(
        by: (bounds.width - size.width) / 2, yBy: (bounds.height - size.height) / 2)
      transform.concat()
      let color = tint
      let layer = NSImage(size: size, flipped: false) { _ in
        NSColor.black.setFill()
        MenuBarGlyph.draw()
        return true
      }
      let tinted = NSImage(size: size, flipped: false) { rect in
        layer.draw(in: rect)
        color.setFill()
        rect.fill(using: .sourceIn)
        return true
      }
      tinted.draw(in: CGRect(origin: .zero, size: size))
      NSGraphicsContext.restoreGraphicsState()
    }
  }

  static func render(
    updateWaiting: Bool, appearance: NSAppearance.Name, scale: Int, name: String,
    selected: Bool = false
  ) throws -> URL {
    let rep = try renderedBitmap(
      updateWaiting: updateWaiting, appearance: appearance, scale: scale, selected: selected)
    let png = try #require(rep.representation(using: .png, properties: [:]))
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("ThoughtsSnapshots", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("\(name).png")
    try png.write(to: url)
    return url
  }

  static func renderedBitmap(
    updateWaiting: Bool, appearance: NSAppearance.Name, scale: Int, selected: Bool = false
  ) throws -> NSBitmapImageRep {
    let dark = appearance == .darkAqua
    let backdrop = Backdrop(frame: CGRect(origin: .zero, size: cell))
    backdrop.appearance = NSAppearance(named: appearance)
    backdrop.fill = dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.93, alpha: 1)
    backdrop.tint = dark ? .white : .black
    if selected {
      backdrop.selection = dark ? NSColor(white: 1, alpha: 0.22) : NSColor(white: 0, alpha: 0.2)
    }
    if updateWaiting { MenuBarGlyph.install(dot: UpdateDotView(), in: backdrop) }
    let rep = try bitmap(for: cell, scale: scale)
    backdrop.cacheDisplay(in: backdrop.bounds, to: rep)
    return rep
  }

  @Test(arguments: [1, 2])
  func theCaretAndBarEdgesLandOnWholePixelsSoTheyAreCrisp(scale: Int) throws {
    let glyph = MenuBarGlyph.image()
    let caretHeightRow = scale * 9
    let row = try Self.alphaRow(of: glyph, scale: scale, row: caretHeightRow)
    #expect(Set(row) == [0, 255])
    #expect(row.filter { $0 == 255 }.count == 3 * scale)
    let barRow = try Self.alphaRow(of: glyph, scale: scale, row: scale * 14)
    #expect(barRow[(2 * scale)..<(11 * scale)].allSatisfy { $0 == 255 })
    #expect(barRow[(13 * scale)..<(15 * scale)].allSatisfy { $0 == 0 })
  }

  @Test func theGlyphIsATemplateSoMacOSTintsIt() {
    #expect(MenuBarGlyph.image().isTemplate)
    #expect(MenuBarGlyph.image().size == MenuBarGlyph.canvas)
  }

  @Test(arguments: [1, 2])
  func theDotAreaOfTheImageIsEmptyAndTheGlyphStaysWhole(scale: Int) throws {
    let image = MenuBarGlyph.image()
    let glyphColumns = Int(MenuBarGlyph.glyphSize.width) * scale
    var inkInGlyphColumns = 0
    for row in 0..<(Int(image.size.height) * scale) {
      let alpha = try Self.alphaRow(of: image, scale: scale, row: row)
      #expect(alpha[glyphColumns...].allSatisfy { $0 == 0 })
      inkInGlyphColumns += alpha[0..<glyphColumns].filter { $0 > 0 }.count
    }
    #expect(inkInGlyphColumns > 0)
    #expect(
      MenuBarGlyph.dotRect.minX - MenuBarGlyph.caret.maxX == MenuBarGlyph.dotGap)
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua], [false, true])
  func anUpdateChangesOnlyThePixelsOfTheDotAndNeverTheItemWidth(
    appearance: NSAppearance.Name, selected: Bool
  ) throws {
    let scale = 2
    let plain = try Self.renderedBitmap(
      updateWaiting: false, appearance: appearance, scale: scale, selected: selected)
    let dotted = try Self.renderedBitmap(
      updateWaiting: true, appearance: appearance, scale: scale, selected: selected)
    #expect(plain.pixelsWide == dotted.pixelsWide)
    #expect(plain.pixelsWide == Int(MenuBarGlyph.buttonLength) * scale)
    let dot = MenuBarGlyph.dotFrame(
      in: CGRect(origin: .zero, size: Self.cell), flipped: false)
    let area = CGRect(
      x: dot.minX * CGFloat(scale), y: (Self.cell.height - dot.maxY) * CGFloat(scale),
      width: dot.width * CGFloat(scale), height: dot.height * CGFloat(scale)
    ).insetBy(dx: -CGFloat(scale), dy: -CGFloat(scale))
    var changed = 0
    for y in 0..<plain.pixelsHigh {
      for x in 0..<plain.pixelsWide {
        let a = try #require(plain.colorAt(x: x, y: y)).usingColorSpace(.deviceRGB)
        let b = try #require(dotted.colorAt(x: x, y: y)).usingColorSpace(.deviceRGB)
        guard a != b else { continue }
        changed += 1
        #expect(area.contains(CGPoint(x: x, y: y)))
      }
    }
    #expect(changed > 0)
  }

  @Test(arguments: [false, true])
  func theDotNeverTouchesTheBarOrTheCaretInTheButton(flipped: Bool) {
    let bounds = CGRect(origin: .zero, size: Self.cell)
    let canvas = MenuBarGlyph.canvas
    let origin = CGPoint(x: bounds.midX - canvas.width / 2, y: bounds.midY - canvas.height / 2)
    func inButton(_ rect: CGRect) -> CGRect {
      let y = flipped ? origin.y + canvas.height - rect.maxY : origin.y + rect.minY
      return CGRect(x: origin.x + rect.minX, y: y, width: rect.width, height: rect.height)
    }
    let dot = MenuBarGlyph.dotFrame(in: bounds, flipped: flipped)
    #expect(!dot.insetBy(dx: -1, dy: -1).intersects(inButton(MenuBarGlyph.bar)))
    #expect(!dot.insetBy(dx: -1, dy: -1).intersects(inButton(MenuBarGlyph.caret)))
    #expect(bounds.contains(dot))
    #expect(dot.size == CGSize(width: MenuBarGlyph.dotDiameter, height: MenuBarGlyph.dotDiameter))
  }

  @Test func theItemIsWideEnoughForTheGlyphAndTheDot() {
    #expect(MenuBarGlyph.buttonLength >= MenuBarGlyph.canvas.width)
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

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua], [false, true])
  func theIconRendersInsideTheSelectedItemShape(
    appearance: NSAppearance.Name, updateWaiting: Bool
  ) throws {
    for scale in Self.scales {
      let name =
        "menubar-selected-\(appearance == .aqua ? "light" : "dark")-\(updateWaiting ? "dot" : "plain")-\(scale)x"
      let url = try Self.render(
        updateWaiting: updateWaiting, appearance: appearance, scale: scale, name: name,
        selected: true)
      let image = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
      #expect(image.pixelsWide == Int(Self.cell.width) * scale)
      #expect(SnapshotTests.colorCount(of: image) > 2)
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

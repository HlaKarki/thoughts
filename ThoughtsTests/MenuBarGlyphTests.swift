import AppKit
import Testing

@testable import Thoughts

@MainActor
struct MenuBarGlyphTests {
  static let cell = CGSize(width: MenuBarGlyph.buttonLength, height: 24)

  static let scales = [1, 2]

  enum Mark: String, CaseIterable {
    case plain
    case blue
    case blueWithDot = "blue-dot"

    var updateWaiting: Bool { self != .plain }
    var differentiate: Bool { self == .blueWithDot }
  }

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

  static func pixel(_ rep: NSBitmapImageRep, x: Int, y: Int) throws -> NSColor {
    let color = try #require(rep.colorAt(x: x, y: y))
    return try #require(color.usingColorSpace(.deviceRGB))
  }

  final class Backdrop: NSView {
    var tint = NSColor.black
    var fill = NSColor.white
    var selection: NSColor?
    var updateWaiting = false

    override func draw(_ dirtyRect: NSRect) {
      fill.setFill()
      bounds.fill()
      if let selection {
        selection.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 1), xRadius: 5, yRadius: 5).fill()
      }
      let color = tint
      let template = MenuBarGlyph.image(updateWaiting: updateWaiting)
      let tinted = NSImage(size: MenuBarGlyph.size, flipped: false) { rect in
        template.draw(in: rect)
        color.setFill()
        rect.fill(using: .sourceIn)
        return true
      }
      tinted.draw(
        in: CGRect(
          x: (bounds.width - MenuBarGlyph.size.width) / 2,
          y: (bounds.height - MenuBarGlyph.size.height) / 2, width: MenuBarGlyph.size.width,
          height: MenuBarGlyph.size.height))
    }
  }

  static func render(
    _ mark: Mark, appearance: NSAppearance.Name, scale: Int, name: String,
    selected: Bool = false
  ) throws -> URL {
    let rep = try renderedBitmap(mark, appearance: appearance, scale: scale, selected: selected)
    let png = try #require(rep.representation(using: .png, properties: [:]))
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("ThoughtsSnapshots", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("\(name).png")
    try png.write(to: url)
    return url
  }

  static func renderedBitmap(
    _ mark: Mark, appearance: NSAppearance.Name, scale: Int, selected: Bool = false
  ) throws -> NSBitmapImageRep {
    let dark = appearance == .darkAqua
    let backdrop = Backdrop(frame: CGRect(origin: .zero, size: cell))
    backdrop.appearance = NSAppearance(named: appearance)
    backdrop.fill = dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.93, alpha: 1)
    backdrop.tint = dark ? .white : .black
    backdrop.updateWaiting = mark.updateWaiting
    if selected {
      backdrop.selection = dark ? NSColor(white: 1, alpha: 0.22) : NSColor(white: 0, alpha: 0.2)
    }
    let caret = UpdateCaretView()
    let dot = UpdateDotView()
    MenuBarGlyph.install(caret: caret, dot: dot, in: backdrop)
    caret.isHidden = !mark.updateWaiting
    dot.isHidden = !mark.differentiate
    let rep = try bitmap(for: cell, scale: scale)
    backdrop.cacheDisplay(in: backdrop.bounds, to: rep)
    return rep
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

  @Test func theGlyphIsATemplateSoMacOSTintsTheBar() {
    for waiting in [false, true] {
      #expect(MenuBarGlyph.image(updateWaiting: waiting).isTemplate)
      #expect(MenuBarGlyph.image(updateWaiting: waiting).size == MenuBarGlyph.size)
    }
  }

  @Test(arguments: [1, 2])
  func theWaitingImageIsTheSameGlyphWithoutItsCaret(scale: Int) throws {
    let plain = MenuBarGlyph.image(updateWaiting: false)
    let waiting = MenuBarGlyph.image(updateWaiting: true)
    let caretColumns = Int(MenuBarGlyph.caret.minX) * scale..<Int(MenuBarGlyph.caret.maxX) * scale
    var caretInk = 0
    for row in 0..<(Int(MenuBarGlyph.size.height) * scale) {
      let a = try Self.alphaRow(of: plain, scale: scale, row: row)
      let b = try Self.alphaRow(of: waiting, scale: scale, row: row)
      #expect(Array(a[..<caretColumns.lowerBound]) == Array(b[..<caretColumns.lowerBound]))
      #expect(b[caretColumns].allSatisfy { $0 == 0 })
      caretInk += a[caretColumns].filter { $0 > 0 }.count
    }
    #expect(caretInk > 0)
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua], [false, true])
  func anUpdateChangesOnlyTheCaretAndTheDotAndNeverTheItemWidth(
    appearance: NSAppearance.Name, selected: Bool
  ) throws {
    let scale = 2
    let bounds = CGRect(origin: .zero, size: Self.cell)
    func area(_ rect: CGRect) -> CGRect {
      let frame = MenuBarGlyph.frame(of: rect, in: bounds, flipped: false)
      return CGRect(
        x: frame.minX * CGFloat(scale), y: (Self.cell.height - frame.maxY) * CGFloat(scale),
        width: frame.width * CGFloat(scale), height: frame.height * CGFloat(scale)
      ).insetBy(dx: -CGFloat(scale), dy: -CGFloat(scale))
    }
    let plain = try Self.renderedBitmap(
      .plain, appearance: appearance, scale: scale, selected: selected)
    for mark in [Mark.blue, .blueWithDot] {
      let other = try Self.renderedBitmap(
        mark, appearance: appearance, scale: scale, selected: selected)
      #expect(plain.pixelsWide == other.pixelsWide)
      #expect(plain.pixelsWide == Int(MenuBarGlyph.buttonLength) * scale)
      var changedInCaret = 0
      var changedInDot = 0
      for y in 0..<plain.pixelsHigh {
        for x in 0..<plain.pixelsWide {
          let a = try Self.pixel(plain, x: x, y: y)
          let b = try Self.pixel(other, x: x, y: y)
          guard a != b else { continue }
          let point = CGPoint(x: x, y: y)
          let inCaret = area(MenuBarGlyph.caret).contains(point)
          let inDot = mark.differentiate && area(MenuBarGlyph.dotRect).contains(point)
          #expect(inCaret || inDot)
          if inCaret { changedInCaret += 1 }
          if inDot { changedInDot += 1 }
        }
      }
      #expect(changedInCaret > 0)
      #expect((changedInDot > 0) == mark.differentiate)
    }
  }

  @Test func theCaretTurnsBlueWhileTheBarKeepsTheSystemTint() throws {
    for appearance in [NSAppearance.Name.aqua, .darkAqua] {
      let rep = try Self.renderedBitmap(.blue, appearance: appearance, scale: 2, selected: true)
      let bounds = CGRect(origin: .zero, size: Self.cell)
      let caret = MenuBarGlyph.frame(of: MenuBarGlyph.caret, in: bounds, flipped: false)
      let caretPixel = try Self.pixel(
        rep, x: Int(caret.midX * 2), y: Int((Self.cell.height - caret.midY) * 2))
      let bar = MenuBarGlyph.frame(of: MenuBarGlyph.bar, in: bounds, flipped: false)
      let barPixel = try Self.pixel(
        rep, x: Int(bar.midX * 2), y: Int((Self.cell.height - bar.midY) * 2))
      #expect(caretPixel.blueComponent > 0.8)
      #expect(caretPixel.redComponent < 0.5)
      #expect(abs(barPixel.redComponent - barPixel.blueComponent) < 0.02)
    }
  }

  @Test(arguments: [false, true])
  func theDotNeverTouchesTheBarOrTheCaretInTheButton(flipped: Bool) {
    let bounds = CGRect(origin: .zero, size: Self.cell)
    let dot = MenuBarGlyph.frame(of: MenuBarGlyph.dotRect, in: bounds, flipped: flipped)
    let bar = MenuBarGlyph.frame(of: MenuBarGlyph.bar, in: bounds, flipped: flipped)
    let caret = MenuBarGlyph.frame(of: MenuBarGlyph.caret, in: bounds, flipped: flipped)
    #expect(!dot.insetBy(dx: -1, dy: -1).intersects(bar))
    #expect(!dot.insetBy(dx: -1, dy: -1).intersects(caret))
    #expect(bounds.contains(dot))
    #expect(dot.size == CGSize(width: MenuBarGlyph.dotDiameter, height: MenuBarGlyph.dotDiameter))
  }

  @Test func theGlyphIsCenteredInTheItem() {
    let bounds = CGRect(origin: .zero, size: Self.cell)
    let frame = MenuBarGlyph.frame(
      of: CGRect(origin: .zero, size: MenuBarGlyph.size), in: bounds, flipped: false)
    #expect(frame.midX == bounds.midX)
    #expect(frame.midY == bounds.midY)
    #expect(MenuBarGlyph.buttonLength >= MenuBarGlyph.size.width)
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua], Mark.allCases)
  func theIconRendersInLightAndDarkInEveryMarkAndInTheSelectedShape(
    appearance: NSAppearance.Name, mark: Mark
  ) throws {
    for scale in Self.scales {
      for selected in [false, true] {
        let name =
          "menubar\(selected ? "-selected" : "")-\(appearance == .aqua ? "light" : "dark")-\(mark.rawValue)-\(scale)x"
        let url = try Self.render(
          mark, appearance: appearance, scale: scale, name: name, selected: selected)
        let image = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
        #expect(image.pixelsWide == Int(Self.cell.width) * scale)
        #expect(image.pixelsHigh == Int(Self.cell.height) * scale)
        #expect(SnapshotTests.colorCount(of: image) > 1)
      }
    }
  }

  @Test func theLabelSaysWhenAnUpdateWaits() {
    #expect(MenuBarGlyph.label(updateWaiting: false) == "Thoughts")
    #expect(MenuBarGlyph.label(updateWaiting: true) == "Thoughts, update available")
  }
}

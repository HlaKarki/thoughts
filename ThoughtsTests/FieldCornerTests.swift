import AppKit
import SwiftUI
import Testing

@testable import Thoughts

@MainActor
@Suite(.serialized, .throwaway)
struct FieldCornerTests {
  static var expectedRadius: CGFloat {
    if #available(macOS 26, *) { 14 } else { 10 }
  }

  struct Box {
    let minX: CGFloat
    let maxX: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    var height: CGFloat { bottom - top }
  }

  static func inputBox(_ harness: PanelHarness) throws -> Box {
    let field = try #require(harness.inputField)
    let aligned = field.alignmentRect(forFrame: field.frame)
    let rect = harness.hosting.convert(aligned, from: field.superview)
    let top = harness.hosting.isFlipped ? rect.minY : harness.hosting.bounds.height - rect.maxY
    let vertical = (InputView.boxHeight - InputField.lineHeight) / 2
    return Box(
      minX: 12, maxX: harness.hosting.bounds.width - 12, top: top - vertical,
      bottom: top + rect.height + vertical)
  }

  static func searchBox(_ harness: PanelHarness) throws -> Box {
    let field = try #require(harness.field(SearchTextField.self))
    let rect = harness.hosting.convert(field.bounds, from: field)
    let flipped = harness.hosting.isFlipped
    let middle = flipped ? rect.midY : harness.hosting.bounds.height - rect.midY
    return Box(minX: 12, maxX: rect.maxX + 10, top: middle - 16, bottom: middle + 16)
  }

  static func searchRightEdge(
    _ box: Box, in image: NSBitmapImageRep, backdrop: [Double]
  ) throws -> CGFloat {
    var x = box.maxX - 8
    let y = (box.top + box.bottom) / 2
    while x < box.maxX + 40, Self.differs(try Self.color(image, x: x, y: y), backdrop) {
      x += 0.5
    }
    return x
  }

  static func color(_ image: NSBitmapImageRep, x: CGFloat, y: CGFloat) throws -> [Double] {
    let scale = CGFloat(SnapshotRenderer.scale)
    let sample = try #require(
      image.colorAt(x: Int((x * scale).rounded(.down)), y: Int((y * scale).rounded(.down)))?
        .usingColorSpace(.deviceRGB))
    return [
      Double(sample.redComponent), Double(sample.greenComponent), Double(sample.blueComponent),
    ]
  }

  static func backdrop(_ appearance: NSAppearance.Name) -> [Double] {
    var result = [0.0, 0.0, 0.0]
    NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
      let color = NSColor.windowBackgroundColor.usingColorSpace(.deviceRGB)
      result = [
        Double(color?.redComponent ?? 0), Double(color?.greenComponent ?? 0),
        Double(color?.blueComponent ?? 0),
      ]
    }
    return result
  }

  static func differs(_ a: [Double], _ b: [Double], by amount: Double = 3.0 / 255) -> Bool {
    HoverPanelTests.distance(a, b) >= amount
  }

  static func visibleExtent(
    from center: CGPoint, dx: CGFloat, dy: CGFloat, angle: Double, in image: NSBitmapImageRep,
    backdrop: [Double], radius: CGFloat
  ) throws -> CGFloat {
    var extent: CGFloat = 0
    var distance = radius - 4
    while distance <= radius + 4 {
      let x = center.x + dx * distance * CGFloat(cos(angle))
      let y = center.y + dy * distance * CGFloat(sin(angle))
      if Self.differs(try Self.color(image, x: x, y: y), backdrop) { extent = distance }
      distance += 0.25
    }
    return extent
  }

  static func cornerProblems(
    _ box: Box, in image: NSBitmapImageRep, backdrop: [Double], radius: CGFloat
  ) throws -> [String] {
    var problems: [String] = []
    let corners: [(x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat)] = [
      (box.minX + radius, box.top + radius, -1, -1),
      (box.maxX - radius, box.top + radius, 1, -1),
      (box.minX + radius, box.bottom - radius, -1, 1),
      (box.maxX - radius, box.bottom - radius, 1, 1),
    ]
    for corner in corners {
      for degrees in stride(from: 5.0, through: 85.0, by: 10.0) {
        let extent = try Self.visibleExtent(
          from: CGPoint(x: corner.x, y: corner.y), dx: corner.dx, dy: corner.dy,
          angle: degrees * .pi / 180, in: image, backdrop: backdrop, radius: radius)
        if abs(extent - radius) > 0.9 {
          problems.append("corner \(corner.dx),\(corner.dy) at \(degrees) deg reaches \(extent)")
        }
      }
    }
    return problems
  }

  static func straightEdgeProblems(
    _ box: Box, in image: NSBitmapImageRep, backdrop: [Double], radius: CGFloat
  ) throws -> [String] {
    var problems: [String] = []
    for y in stride(from: box.top + radius + 1, through: box.bottom - radius - 1, by: 1) {
      for x in [box.minX + 0.5, box.maxX - 0.75] {
        if !Self.differs(try Self.color(image, x: x, y: y), backdrop) {
          problems.append("edge at \(x),\(y) is empty")
        }
      }
      for x in [box.minX - 1.5, box.maxX + 1.5] {
        if Self.differs(try Self.color(image, x: x, y: y), backdrop) {
          problems.append("outside at \(x),\(y) is drawn")
        }
      }
    }
    return problems
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua], [1, 3])
  func bothFieldsDrawTheSameFixedCornerAtEveryHeight(
    _ appearance: NSAppearance.Name, _ lines: Int
  ) async throws {
    let tone = appearance == .aqua ? "light" : "dark"
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two", "three"])
      try await harness.show()
      harness.input.text = Array(repeating: "line", count: lines).joined(separator: "\n")
      await harness.settle("after typing \(lines) lines")
      let image = try HoverPanelTests.flatRender(
        harness, "field-corners-\(lines)-\(tone)", appearance: appearance)
      let backdrop = Self.backdrop(appearance)
      let radius = Self.expectedRadius
      let input = try Self.inputBox(harness)
      var search = try Self.searchBox(harness)
      search = Box(
        minX: search.minX, maxX: try Self.searchRightEdge(search, in: image, backdrop: backdrop),
        top: search.top, bottom: search.bottom)
      if lines == 1 {
        #expect(abs(input.height - InputView.boxHeight) < 0.5)
      } else {
        #expect(input.height > InputView.boxHeight + 20)
      }
      for (name, box) in [("input", input), ("search", search)] {
        let corners = try Self.cornerProblems(box, in: image, backdrop: backdrop, radius: radius)
        #expect(corners.isEmpty, "\(tone) \(lines) \(name): \(corners.prefix(4))")
        let edges = try Self.straightEdgeProblems(
          box, in: image, backdrop: backdrop, radius: radius)
        #expect(edges.isEmpty, "\(tone) \(lines) \(name): \(edges.prefix(4))")
      }
      #expect(PanelHarness.ownWindowsOnScreens().isEmpty)
    }
  }

  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func aOneLineInputHasNoLineLeftOfItsText(_ appearance: NSAppearance.Name) async throws {
    let tone = appearance == .aqua ? "light" : "dark"
    try await PanelHarness.run { harness in
      try harness.seed(["one", "two"])
      try await harness.show()
      await harness.settle("after show")
      let image = try HoverPanelTests.flatRender(
        harness, "field-corners-gutter-\(tone)", appearance: appearance)
      let input = try Self.inputBox(harness)
      let field = try #require(harness.inputField)
      let textLeft = harness.hosting.convert(field.bounds, from: field).minX
      let fill = try Self.color(image, x: input.minX + 3, y: (input.top + input.bottom) / 2)
      let scale = CGFloat(SnapshotRenderer.scale)
      var stray: [String] = []
      for row in stride(
        from: input.top + Self.expectedRadius + 1, through: input.bottom - Self.expectedRadius - 1,
        by: 1)
      {
        var x = input.minX + 3
        while x < textLeft - 1 {
          let sample = try Self.color(image, x: x, y: row)
          if HoverPanelTests.distance(sample, fill) > 1.5 / 255 {
            stray.append("\(x),\(row)")
          }
          x += 1 / scale
        }
      }
      #expect(stray.isEmpty, "\(tone): \(stray.prefix(6))")
    }
  }

  @Test func bothFieldsReadTheirRadiusFromOneSource() {
    let rect = CGRect(x: 0, y: 0, width: 200, height: 60)
    let radius = FieldShape.cornerRadius
    #expect(radius == Self.expectedRadius)
    let reference: Path
    if #available(macOS 26, *) {
      reference = RoundedRectangle(cornerRadius: radius).path(in: rect)
    } else {
      reference = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
    #expect(FieldShape().path(in: rect) == reference)
    for height in [32.0, 38.0, 60.0, 120.0] {
      let box = CGRect(x: 0, y: 0, width: 200, height: height)
      #expect(FieldShape().path(in: box).boundingRect == box)
    }
    let inset = FieldShape().inset(by: 1)
    let smaller: Path
    if #available(macOS 26, *) {
      smaller = RoundedRectangle(cornerRadius: radius - 1).path(in: rect.insetBy(dx: 1, dy: 1))
    } else {
      smaller = RoundedRectangle(cornerRadius: radius - 1, style: .continuous)
        .path(in: rect.insetBy(dx: 1, dy: 1))
    }
    #expect(inset.path(in: rect) == smaller)
  }
}

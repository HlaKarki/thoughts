import AppKit
import SwiftUI

struct InputView: View {
  let list: ListModel
  @Bindable var input: InputModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 8) {
      InputField(
        text: $input.text, isFocused: list.focus == .input,
        onFocus: { list.fieldDidTakeFocus(.input) }
      )
      .padding(.horizontal, 10)
      .frame(height: 38)
      .background(inputFill, in: FieldShape(cornerRadius: 10))
      .overlay {
        FieldShape(cornerRadius: 10)
          .strokeBorder(Color.primary.opacity(0.13), lineWidth: 1)
      }
      ActionBar(
        focus: list.focus,
        hasEntries: !list.visible.isEmpty,
        inputIsEmpty: input.text.isEmpty,
        hasAttachment: input.attachment != nil,
        isPreviewing: list.isPreviewing, feedback: list.shownFeedback)
    }
    .padding(.top, 10)
    .padding(.bottom, 12)
    .padding(.horizontal, 12)
  }

  private var inputFill: Color {
    colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.7)
  }
}

struct AttachmentPreview: View {
  static let maxHeight: CGFloat = 200
  static let cornerRadius: CGFloat = 10
  static let verticalInset: CGFloat = 8

  let image: NSImage
  let onRemove: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  static func height(for image: NSImage, width: CGFloat) -> CGFloat {
    let size = image.size
    guard size.width > 0, size.height > 0 else { return maxHeight }
    return min(maxHeight, (width * size.height / size.width).rounded())
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
    Color(nsColor: .windowBackgroundColor)
      .overlay { Color.primary.opacity(0.06) }
      .frame(height: Self.height(for: image, width: PanelController.width - 24))
      .overlay {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      }
      .clipShape(shape)
      .overlay { shape.strokeBorder(border, lineWidth: 1) }
      .overlay(alignment: .topTrailing) {
        Button(action: onRemove) {
          ZStack {
            Circle().fill(Color.black.opacity(0.55))
            RemoveCross()
              .stroke(Color.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
              .frame(width: 8, height: 8)
          }
          .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .padding(8)
        .accessibilityLabel("Remove image")
      }
      .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 1, y: 1)
      .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 12, y: 8)
      .accessibilityElement(children: .contain)
  }

  private var border: Color {
    colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
  }
}

private struct RemoveCross: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    return path
  }
}

struct ListScrim: View {
  var body: some View {
    Color(nsColor: .windowBackgroundColor)
      .opacity(0.5)
      .allowsHitTesting(false)
  }
}

struct DropTargetView: View {
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
    VStack(spacing: 0) {
      Image(systemName: "square.and.arrow.down")
        .font(.system(size: 22, weight: .regular))
        .foregroundStyle(Color(nsColor: .systemGray))
        .padding(.bottom, 12)
      Text("Drop to add a thought")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color(nsColor: .labelColor))
        .padding(.bottom, 8)
      Text("Images and text are saved as they are. Any other file is saved as its path.")
        .font(.system(size: 12))
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        .multilineTextAlignment(.center)
        .lineSpacing(3)
    }
    .padding(.horizontal, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      shape.fill(Color(nsColor: .windowBackgroundColor))
        .overlay { shape.fill(Color.primary.opacity(0.04)) }
    }
    .overlay {
      shape.strokeBorder(
        Color.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .accessibilityElement(children: .combine)
    .allowsHitTesting(false)
  }
}

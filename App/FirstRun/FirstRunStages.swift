import AppKit
import SwiftUI
import ThoughtsCore

struct FirstRunStage: View {
  let model: FirstRunModel

  var body: some View {
    ZStack(alignment: .topLeading) {
      switch model.step {
      case .summonKey: SummonStage()
      case .gesture: CaptureStage()
      case .accessibility: AccessibilityStage()
      case .storage: StorageStage(folder: model.storageFolder.lastPathComponent)
      case .clipboard: ClipboardStage(keycap: model.captureKeycap)
      case .done: EmptyView()
      }
    }
    .frame(
      width: FirstRunView.size.width, height: FirstRunView.stageHeight, alignment: .topLeading
    )
    .accessibilityHidden(true)
  }
}

private struct StageCard<Content: View>: View {
  var radius: CGFloat = 12
  @ViewBuilder let content: Content
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = FirstRunPalette(scheme: colorScheme)
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    content
      .background(palette.card, in: shape)
      .overlay { shape.strokeBorder(palette.cardEdge, lineWidth: 1) }
      .clipShape(shape)
      .shadow(color: palette.cardShadow, radius: 14, y: 12)
  }
}

private struct StageKey: View {
  let label: String
  var size: CGSize = CGSize(width: 64, height: 64)
  var fontSize: CGFloat = 28
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let dark = colorScheme == .dark
    let shape = RoundedRectangle(cornerRadius: size.height * 0.19, style: .continuous)
    Text(verbatim: label)
      .font(.system(size: fontSize, weight: .medium))
      .foregroundStyle(Color(nsColor: .labelColor))
      .frame(width: size.width, height: size.height)
      .background(
        LinearGradient(
          colors: dark
            ? [Color(white: 0.188), Color(white: 0.153)] : [.white, Color(white: 0.965)],
          startPoint: .top, endPoint: .bottom),
        in: shape
      )
      .overlay { shape.strokeBorder(Color.white.opacity(dark ? 0.07 : 0), lineWidth: 1) }
      .background(
        shape.fill(dark ? Color(white: 0.04) : Color(white: 0.8)).offset(y: size.height * 0.05)
      )
      .shadow(color: .black.opacity(dark ? 0.5 : 0.12), radius: 9, y: 8)
  }
}

private struct Bar: View {
  let width: CGFloat
  var height: CGFloat = 6
  var strong = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Capsule()
      .fill(Color(nsColor: .labelColor).opacity(strong ? 0.6 : (colorScheme == .dark ? 0.3 : 0.16)))
      .frame(width: width, height: height)
  }
}

private struct MiniPanel<Rows: View>: View {
  @ViewBuilder let rows: Rows
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = FirstRunPalette(scheme: colorScheme)
    StageCard {
      VStack(alignment: .leading, spacing: 11) {
        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(palette.inset).frame(height: 18)
        rows
        Spacer(minLength: 0)
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(palette.inset)
          .frame(height: 22)
          .overlay(alignment: .leading) {
            Capsule().fill(palette.caret).frame(width: 2, height: 12).padding(.leading, 8)
          }
      }
      .padding(12)
      .frame(width: 150, height: 136, alignment: .topLeading)
    }
  }
}

private struct SummonStage: View {
  var body: some View {
    ZStack(alignment: .topLeading) {
      HStack(spacing: 12) {
        StageKey(label: "⌥")
        StageKey(label: "N")
      }
      .offset(x: 132, y: 58)
      MiniPanel {
        Bar(width: 104, strong: true)
        Bar(width: 78)
        Bar(width: 96)
        Bar(width: 60)
      }
      .offset(x: 428, y: 22)
    }
  }
}

private struct CaptureStage: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = FirstRunPalette(scheme: colorScheme)
    ZStack(alignment: .topLeading) {
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: "Tram 28 climbs through Graça on the old tracks.")
          .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
          .padding(.leading, 4)
        Text(verbatim: "It fills up after 10, so get on early.")
          .foregroundStyle(Color(nsColor: .labelColor))
          .padding(.horizontal, 4)
          .padding(.vertical, 1)
          .background(
            palette.caret.opacity(0.32), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
      }
      .font(.system(size: 14))
      .offset(x: 52, y: 50)
      HStack(spacing: 6) {
        StageKey(label: "⇧", size: CGSize(width: 36, height: 34), fontSize: 16)
        StageKey(label: "⇧", size: CGSize(width: 36, height: 34), fontSize: 16)
      }
      .offset(x: 56, y: 118)
      MiniPanel {
        Bar(width: 78)
        Bar(width: 96)
        VStack(alignment: .leading, spacing: 5) {
          Bar(width: 104, strong: true)
          Bar(width: 64, strong: true)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
          palette.caret.opacity(0.22), in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .padding(.horizontal, -6)
        .padding(.vertical, -4)
      }
      .offset(x: 428, y: 22)
    }
  }
}

private struct AccessibilityStage: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = FirstRunPalette(scheme: colorScheme)
    StageCard(radius: 10) {
      VStack(spacing: 0) {
        row(name: "Terminal", on: true, dim: true) { placeholderIcon }
        Rectangle().fill(palette.hairline).frame(height: 1).padding(.horizontal, 14)
        row(name: "Thoughts", on: true, dim: false) {
          Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: 24, height: 24)
        }
        Rectangle().fill(palette.hairline).frame(height: 1).padding(.horizontal, 14)
        row(name: "Zoom", on: false, dim: true) { placeholderIcon }
      }
      .frame(width: 340)
    }
    .offset(x: 110, y: 34)
  }

  private var placeholderIcon: some View {
    RoundedRectangle(cornerRadius: 6, style: .continuous)
      .fill(FirstRunPalette(scheme: colorScheme).inset)
      .frame(width: 24, height: 24)
  }

  private func row(
    name: String, on: Bool, dim: Bool, @ViewBuilder icon: () -> some View
  ) -> some View {
    let palette = FirstRunPalette(scheme: colorScheme)
    return HStack(spacing: 10) {
      icon()
      Text(verbatim: name)
        .font(.system(size: 13))
        .foregroundStyle(Color(nsColor: .labelColor))
      Spacer(minLength: 0)
      Capsule()
        .fill(on ? palette.caret : palette.track)
        .frame(width: 38, height: 22)
        .overlay(alignment: on ? .trailing : .leading) {
          Circle().fill(.white).frame(width: 18, height: 18).padding(2)
        }
    }
    .padding(.horizontal, 14)
    .frame(height: 44)
    .opacity(dim ? 0.4 : 1)
  }
}

private struct StorageStage: View {
  let folder: String
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = FirstRunPalette(scheme: colorScheme)
    StageCard(radius: 10) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 7) {
          Image(systemName: "folder.fill")
            .font(.system(size: 10))
            .foregroundStyle(palette.caret)
          Text(verbatim: folder).foregroundStyle(Color(nsColor: .secondaryLabelColor))
          Text(verbatim: "/").foregroundStyle(Color(nsColor: .tertiaryLabelColor))
          Text(verbatim: "20261127-112820-03yhkj5e.md")
            .fontWeight(.medium)
            .foregroundStyle(Color(nsColor: .labelColor))
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 28)
        Rectangle().fill(palette.hairline).frame(height: 1)
        VStack(alignment: .leading, spacing: 0) {
          Group {
            Text(verbatim: "---")
            Text(verbatim: "created: 2026-11-27T11:28:20")
            Text(verbatim: "source: Safari, Lisbon tram tips")
            Text(verbatim: "---")
          }
          .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
          Text(verbatim: "It fills up after 10, so get on early.")
            .foregroundStyle(Color(nsColor: .labelColor))
            .padding(.top, 4)
        }
        .font(.system(size: 11, design: .monospaced))
        .lineSpacing(3)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
      }
      .frame(width: 360, alignment: .leading)
    }
    .offset(x: 100, y: 24)
  }
}

private struct ClipboardStage: View {
  let keycap: KeycapContent?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = FirstRunPalette(scheme: colorScheme)
    ZStack(alignment: .topLeading) {
      StageCard(radius: 8) {
        VStack(alignment: .leading, spacing: 7) {
          Bar(width: 70, height: 7, strong: true)
          Bar(width: 110, height: 5)
          Bar(width: 96, height: 5)
          Spacer(minLength: 0)
          RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(palette.caret, lineWidth: 1.5)
            .frame(width: 60, height: 18)
        }
        .padding(12)
        .frame(width: 150, height: 100, alignment: .topLeading)
      }
      .offset(x: 64, y: 36)
      Text(verbatim: "⌘ C")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Color(nsColor: .labelColor))
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(palette.inset, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 5, y: 4)
        .offset(x: 196, y: 56)
      OfferChipView(kind: .clipboard, thumbnail: nil, keycap: keycap)
        .frame(width: 300)
        .offset(x: 250, y: 104)
    }
  }
}

import KeyboardShortcuts
import SwiftUI
import ThoughtsCore

struct FirstRunView: View {
  static let size = CGSize(width: 560, height: 440)
  static let stageHeight: CGFloat = 180
  static let footerHeight: CGFloat = 64

  @Bindable var model: FirstRunModel
  @Environment(\.colorScheme) private var colorScheme

  private var palette: FirstRunPalette { FirstRunPalette(scheme: colorScheme) }

  var body: some View {
    VStack(spacing: 0) {
      FirstRunStage(model: model)
        .frame(width: Self.size.width, height: Self.stageHeight)
        .background(palette.stage)
        .clipped()
        .overlay(alignment: .bottom) { Rectangle().fill(palette.hairline).frame(height: 1) }
      content
        .padding(.horizontal, 36)
        .padding(.top, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      footer
    }
    .frame(width: Self.size.width, height: Self.size.height)
    .background(palette.window)
    .task(id: model.step) {
      switch model.step {
      case .accessibility: await model.watchAccessibility()
      case .clipboard: await model.readWatchedFolders()
      default: break
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch model.step {
    case .summonKey: SummonKeyStep(model: model)
    case .gesture: GestureStep(model: model)
    case .accessibility: AccessibilityStep(model: model)
    case .storage: StorageStep(model: model)
    case .clipboard: ClipboardStep(model: model)
    case .done: EmptyView()
    }
  }

  private var footer: some View {
    HStack(spacing: 0) {
      progress
      Spacer()
      Button("Back") { model.back() }
        .disabled(model.step == .summonKey)
        .padding(.trailing, 8)
      Button(primaryTitle) { model.advance() }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(!model.canContinue)
        .frame(minWidth: 84)
    }
    .controlSize(.large)
    .padding(.leading, 36)
    .padding(.trailing, 20)
    .frame(height: Self.footerHeight)
  }

  private var progress: some View {
    HStack(spacing: 4) {
      ForEach(1...FirstRunFlow.numberedSteps, id: \.self) { number in
        Capsule()
          .fill(
            number <= (FirstRunFlow.number(of: model.step) ?? 0) ? palette.caret : palette.track
          )
          .frame(width: 20, height: 3)
      }
    }
    .accessibilityHidden(true)
  }

  private var primaryTitle: LocalizedStringKey {
    switch model.step {
    case .clipboard: "Done"
    default: "Continue"
    }
  }
}

struct FirstRunPalette {
  let scheme: ColorScheme

  var isDark: Bool { scheme == .dark }
  var window: Color { isDark ? Color(white: 0.118) : .white }
  var stage: Color { isDark ? Color(white: 0.075) : Color(white: 0.945) }
  var hairline: Color { isDark ? Color(white: 0.173) : Color(white: 0.898) }
  var card: Color { isDark ? Color(white: 0.137) : .white }
  var cardEdge: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }
  var cardShadow: Color { Color.black.opacity(isDark ? 0.5 : 0.12) }
  var inset: Color { isDark ? Color(white: 0.18) : Color(white: 0.933) }
  var field: Color { isDark ? Color(white: 0.165) : .white }
  var fieldEdge: Color { isDark ? Color(white: 0.22) : Color(white: 0.84) }
  var track: Color { isDark ? Color(white: 0.227) : Color(white: 0.86) }
  var bar: Color { Color(nsColor: .labelColor).opacity(isDark ? 0.32 : 0.18) }
  var caret: Color { Color(nsColor: .systemBlue) }
  var choiceFill: Color { isDark ? Color(white: 0.145) : Color(white: 0.97) }
}

struct StepHeader: View {
  let step: FirstRunStep
  let title: LocalizedStringKey
  let message: Text

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let number = FirstRunFlow.number(of: step) {
        Text("Step \(number) of \(FirstRunFlow.numberedSteps)")
          .textCase(.uppercase)
          .font(.system(size: 11, weight: .medium))
          .tracking(0.66)
          .foregroundStyle(Color(nsColor: .secondaryLabelColor))
      }
      Text(title)
        .font(.system(size: 26, weight: .bold))
        .tracking(-0.52)
        .foregroundStyle(Color(nsColor: .labelColor))
        .padding(.top, 8)
      message
        .font(.system(size: 13))
        .lineSpacing(3)
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct HelpText: View {
  let text: LocalizedStringKey

  var body: some View {
    Text(text)
      .font(.system(size: 12))
      .lineSpacing(2)
      .foregroundStyle(Color(nsColor: .secondaryLabelColor))
      .fixedSize(horizontal: false, vertical: true)
  }
}

private struct SummonKeyStep: View {
  let model: FirstRunModel

  private var message: Text {
    Text(verbatim: MenuBarCopy.summonKeyMessage(iconShown: model.preferences.showsMenuBarIcon))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StepHeader(step: .summonKey, title: "Pick a key to open Thoughts", message: message)
      HStack(spacing: 12) {
        ShortcutRecorder(for: .summon) { model.summonKeyChanged($0) }
          .fixedSize()
        HelpText(text: "Click it and press a new key to change it.")
      }
      .padding(.top, 18)
    }
  }
}

private struct ChoiceCard<Trailing: View>: View {
  let selected: Bool
  let title: LocalizedStringKey
  let select: () -> Void
  @ViewBuilder let trailing: Trailing
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = FirstRunPalette(scheme: colorScheme)
    let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
    HStack(spacing: 8) {
      Text(title)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(
          Color(nsColor: selected ? .labelColor : .secondaryLabelColor)
        )
        .lineLimit(1)
        .fixedSize()
      Spacer(minLength: 0)
      trailing
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
    .background(selected ? palette.caret.opacity(0.12) : palette.choiceFill, in: shape)
    .overlay {
      shape.strokeBorder(
        selected ? palette.caret : palette.fieldEdge, lineWidth: selected ? 1.5 : 1)
    }
    .contentShape(shape)
    .onTapGesture(perform: select)
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction(.default, select)
  }
}

private struct GestureStep: View {
  let model: FirstRunModel

  private var preferences: Preferences { model.preferences }
  private var usesShortcut: Bool { preferences.captureMethod == .shortcut }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StepHeader(
        step: .gesture, title: "Pick how to save from any app",
        message: Text("Saves the text you selected, or what you copied in the last 2 minutes."))
      HStack(spacing: 10) {
        ChoiceCard(selected: !usesShortcut, title: Modifier.shift.twiceTitle) {
          preferences.captureMethod = .doubleTap(.shift)
          model.captureChanged()
        } trailing: {
          Keycap(content: .doubled(.shift))
        }
        .fixedSize()
        ChoiceCard(selected: usesShortcut, title: "Use a shortcut") {
          preferences.captureMethod = .shortcut
          model.captureChanged()
        } trailing: {
          ShortcutRecorder(for: .capture) { _ in
            if !usesShortcut { preferences.captureMethod = .shortcut }
            model.captureChanged()
          }
          .fixedSize()
        }
      }
      .padding(.top, 18)
    }
  }
}

private struct AccessibilityStep: View {
  let model: FirstRunModel

  private var message: Text {
    let pane = SystemServices.accessibilityPaneName
    guard let keycap = model.captureKeycap else {
      return Text(
        "Find Thoughts under \(pane) and switch it on, so Thoughts can read the text you select and its window."
      )
    }
    return Text(
      "Find Thoughts under \(pane) and switch it on, so \(keycap.inline) can read the text you selected and its window."
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StepHeader(
        step: .accessibility, title: "Turn on Thoughts in System Settings", message: message)
      HStack(spacing: 14) {
        if !model.state.accessibilityGranted {
          Button("Open System Settings") { model.openAccessibility() }
            .controlSize(.large)
        }
        status
      }
      .padding(.top, 18)
    }
  }

  @ViewBuilder
  private var status: some View {
    if model.state.accessibilityGranted {
      HStack(spacing: 7) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 16))
          .foregroundStyle(Color(nsColor: .systemGreen))
        Text("Allowed")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Color(nsColor: .labelColor))
      }
    } else if model.accessibilityRequested {
      HStack(spacing: 7) {
        Circle().fill(Color(nsColor: .systemOrange)).frame(width: 7, height: 7)
        Text("Waiting for the switch")
          .font(.system(size: 12))
          .foregroundStyle(Color(nsColor: .secondaryLabelColor))
      }
    }
  }
}

private struct StorageStep: View {
  @Bindable var model: FirstRunModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let palette = FirstRunPalette(scheme: colorScheme)
    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
    VStack(alignment: .leading, spacing: 0) {
      StepHeader(
        step: .storage, title: "Choose where thoughts are saved",
        message: Text(
          "Each thought is a plain Markdown file. Pick a folder in iCloud Drive or Dropbox to sync your Macs."
        ))
      HStack(spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: "folder.fill")
            .font(.system(size: 12))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
          Text(verbatim: model.storageText)
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .labelColor))
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: 300, height: 32)
        .background(palette.field, in: shape)
        .overlay { shape.strokeBorder(palette.fieldEdge, lineWidth: 1) }
        Button("Change…") { Task { await model.changeStorage() } }
          .controlSize(.large)
          .disabled(model.isChangingStorage)
      }
      .padding(.top, 18)
      if let error = model.storageError {
        Text(verbatim: error)
          .font(.system(size: 12))
          .foregroundStyle(Color(nsColor: .systemOrange))
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 8)
      }
    }
  }
}

private struct ClipboardStep: View {
  let model: FirstRunModel
  @Environment(\.colorScheme) private var colorScheme

  private var message: Text {
    guard let keycap = model.captureKeycap else {
      return Text(
        "When you copy an image or take a screenshot, an offer appears at the edge of the screen. Click it to keep it."
      )
    }
    return Text(
      "When you copy an image or take a screenshot, an offer appears at the edge of the screen. Press \(keycap.inline) to keep it."
    )
  }

  private var note: LocalizedStringKey? {
    if model.clipboardAccess == .alwaysDeny {
      return
        "macOS is set to never let Thoughts paste from other apps, so offers show no preview. You can change this in System Settings under Privacy & Security, Paste from Other Apps."
    }
    if model.showsClipboardPromptNote {
      return
        "If macOS asks whether Thoughts can paste from other apps, choose Allow Paste so offers show a preview."
    }
    return nil
  }

  private var folderList: String {
    model.watchedFolders.map { PathText.abbreviated($0, home: model.home) }
      .joined(separator: ", ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StepHeader(step: .clipboard, title: "Keep the images you copy", message: message)
      if let note {
        HStack(alignment: .top, spacing: 8) {
          Capsule()
            .fill(FirstRunPalette(scheme: colorScheme).track)
            .frame(width: 3)
          HelpText(text: note)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 16)
      }
      Text("Thoughts also offers new images saved in \(folderList).")
        .font(.system(size: 12))
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        .lineLimit(2)
        .padding(.top, 10)
    }
  }
}

import KeyboardShortcuts
import SwiftUI
import ThoughtsCore

struct FirstRunView: View {
  static let size = CGSize(width: 480, height: 385)
  static let titlebarHeight: CGFloat = 32
  static let contentHeight: CGFloat = 300

  @Bindable var model: FirstRunModel
  @Environment(\.colorScheme) private var colorScheme

  private var palette: Palette { Palette(scheme: colorScheme) }

  var body: some View {
    VStack(spacing: 0) {
      Color.clear.frame(height: Self.titlebarHeight)
      content
        .padding(.horizontal, 33)
        .frame(width: Self.size.width, height: Self.contentHeight, alignment: .topLeading)
      Rectangle().fill(palette.divider).frame(height: 1)
      footer
    }
    .frame(width: Self.size.width, height: Self.size.height)
    .background(palette.firstRunWindow)
    .task(id: model.step) {
      if model.step == .accessibility { await model.watchAccessibility() }
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
      dots
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
    .controlSize(.regular)
    .padding(.horizontal, 20)
    .frame(height: Self.size.height - Self.titlebarHeight - Self.contentHeight - 1)
  }

  private var dots: some View {
    HStack(spacing: 6) {
      ForEach(1...FirstRunFlow.numberedSteps, id: \.self) { number in
        Circle()
          .fill(
            number == (FirstRunFlow.number(of: model.step) ?? 0)
              ? palette.dotActive : palette.dotIdle
          )
          .frame(width: 6, height: 6)
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

struct StepHeader: View {
  let step: FirstRunStep
  let title: LocalizedStringKey
  let message: Text

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let number = FirstRunFlow.number(of: step) {
        Text("Step \(number) of \(FirstRunFlow.numberedSteps)")
          .font(.system(size: 13))
          .foregroundStyle(Color.helpGray)
          .frame(height: 18)
          .padding(.top, 11)
      }
      Text(title)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Color(nsColor: .labelColor))
        .frame(height: 22, alignment: .leading)
        .padding(.top, 4)
      message
        .font(.system(size: 13))
        .lineSpacing(2)
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct FieldLabel: View {
  let text: LocalizedStringKey

  var body: some View {
    Text(text)
      .font(.system(size: 13))
      .foregroundStyle(Color(nsColor: .labelColor))
      .frame(height: 18)
  }
}

struct HelpText: View {
  let text: LocalizedStringKey

  var body: some View {
    Text(text)
      .font(.system(size: 11))
      .lineSpacing(2)
      .foregroundStyle(Color.helpGray)
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
      FieldLabel(text: "Summon key").padding(.top, 24)
      ShortcutRecorder(for: .summon) { model.summonKeyChanged($0) }
        .frame(width: 220, alignment: .leading)
        .padding(.top, 6)
      HelpText(text: "Click the field and press a new key to change it.").padding(.top, 6)
    }
  }
}

private struct RadioDot: View {
  let selected: Bool

  var body: some View {
    ZStack {
      Circle().fill(selected ? Color(nsColor: .controlAccentColor) : Color(nsColor: .controlColor))
      Circle().strokeBorder(Color(nsColor: .separatorColor), lineWidth: selected ? 0 : 1)
      if selected { Circle().fill(.white).frame(width: 6, height: 6) }
    }
    .frame(width: 16, height: 16)
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
        message: Text("Press it to save the selected text, or what you just copied, as a thought."))
      Button {
        preferences.captureMethod = .doubleTap(.shift)
        model.captureChanged()
      } label: {
        HStack(spacing: 8) {
          RadioDot(selected: !usesShortcut)
          Text("Press Shift twice").foregroundStyle(Color(nsColor: .labelColor))
          Keycap(content: .doubled(.shift))
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.top, 20)
      HStack(spacing: 8) {
        Button {
          preferences.captureMethod = .shortcut
          model.captureChanged()
        } label: {
          HStack(spacing: 8) {
            RadioDot(selected: usesShortcut)
            Text("Use a shortcut").foregroundStyle(Color(nsColor: .labelColor))
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        ShortcutRecorder(for: .capture) { _ in
          if !usesShortcut { preferences.captureMethod = .shortcut }
          model.captureChanged()
        }
        .frame(width: 150)
      }
      .padding(.top, 10)
    }
    .font(.system(size: 13))
  }
}

private struct AccessibilityStep: View {
  let model: FirstRunModel
  @Environment(\.colorScheme) private var colorScheme

  private var reason: Text {
    guard let keycap = model.captureKeycap else {
      return Text("Reads the text you select and the title of the window you're in.")
    }
    return Text("Reads the text you selected when you press \(keycap.inline).")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StepHeader(
        step: .accessibility, title: "Allow Accessibility",
        message: Text("macOS asks for this so the capture gesture works in other apps."))
      HStack(alignment: .center, spacing: 12) {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(Palette(scheme: colorScheme).selection)
          .frame(width: 28, height: 28)
          .overlay {
            Image(systemName: "accessibility")
              .font(.system(size: 15))
              .foregroundStyle(Color(nsColor: .secondaryLabelColor))
          }
        VStack(alignment: .leading, spacing: 0) {
          Text(verbatim: SystemServices.accessibilityPaneName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(nsColor: .labelColor))
          reason
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        status
      }
      .padding(14)
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(Palette(scheme: colorScheme).divider, lineWidth: 1)
      }
      .padding(.top, 20)
      HelpText(text: "Turn on Thoughts in System Settings, then come back.").padding(.top, 8)
    }
  }

  @ViewBuilder
  private var status: some View {
    if model.state.accessibilityGranted {
      HStack(spacing: 6) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 16))
          .foregroundStyle(Color(nsColor: .systemGreen))
        Text("Allowed")
          .font(.system(size: 13))
          .foregroundStyle(Color(nsColor: .secondaryLabelColor))
      }
    } else {
      Button("Open Settings") { model.openAccessibility() }
    }
  }
}

private struct StorageStep: View {
  @Bindable var model: FirstRunModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StepHeader(
        step: .storage, title: "Choose where thoughts are saved",
        message: Text(
          "Each thought is a plain file in this folder. You can open, sync or back it up like any other file."
        ))
      FieldLabel(text: "Storage folder").padding(.top, 20)
      HStack(spacing: 8) {
        HStack(spacing: 8) {
          Image(systemName: "folder.fill").foregroundStyle(Color(nsColor: .systemGray))
          Text(verbatim: model.storageText)
            .foregroundStyle(Color(nsColor: .labelColor))
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
          Palette(scheme: colorScheme).field,
          in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(Palette(scheme: colorScheme).fieldBorder, lineWidth: 1)
        }
        Button("Change…") { Task { await model.changeStorage() } }
          .disabled(model.isChangingStorage)
      }
      .padding(.top, 6)
      HelpText(
        text:
          "Thoughts makes the folder if it isn't there. A folder inside iCloud Drive or Dropbox syncs to your other Macs."
      )
      .padding(.top, 6)
      if let error = model.storageError {
        Text(verbatim: error)
          .font(.system(size: 11))
          .foregroundStyle(Color(nsColor: .systemOrange))
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 6)
      }
    }
  }
}

private struct ClipboardStep: View {
  let model: FirstRunModel

  private var message: Text {
    guard let keycap = model.captureKeycap else {
      return Text(
        "When you copy an image, a small offer appears at the edge of the screen. Click it to keep it."
      )
    }
    return Text(
      "When you copy an image, a small offer appears at the edge of the screen. Press \(keycap.inline) to keep it."
    )
  }

  private var folderList: String {
    model.watchedFolders.map { PathText.abbreviated($0, home: model.home) }
      .joined(separator: ", ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StepHeader(step: .clipboard, title: "Saving copied images", message: message)
      OfferChipView(kind: .clipboard, thumbnail: nil, keycap: model.captureKeycap)
        .padding(.top, 14)
        .padding(.bottom, -4)
      if model.clipboardAccess == .alwaysDeny {
        InfoNote(
          text:
            "macOS is set to never let Thoughts paste from other apps, so offers show no preview. You can change this in System Settings under Privacy & Security, Paste from Other Apps."
        )
        .padding(.top, 12)
      } else if model.showsClipboardPromptNote {
        InfoNote(
          text:
            "If macOS asks if Thoughts can paste from other apps, choose Allow Paste, and offers show a preview of the image. You can change this later in System Settings under Privacy & Security, Paste from Other Apps."
        )
        .padding(.top, 12)
      }
      Text("Thoughts also offers new images saved in \(folderList).")
        .font(.system(size: 11))
        .foregroundStyle(Color.helpGray)
        .lineLimit(2)
        .padding(.top, 10)
    }
  }
}

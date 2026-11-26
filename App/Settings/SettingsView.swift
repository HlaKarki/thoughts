import KeyboardShortcuts
import SwiftUI
import ThoughtsCore

struct SettingsView: View {
  static let size = CGSize(width: 520, height: 820)

  let model: SettingsModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        SettingsGroup(title: "Keys") { KeysSettings(model: model) }
        SettingsGroup(title: "Saving") { SavingSettings(model: model) }
        SettingsGroup(title: "Panel") { PanelSettings(model: model) }
      }
      .padding(.horizontal, 22)
      .padding(.top, 8)
      .padding(.bottom, 22)
    }
    .frame(width: Self.size.width, height: Self.size.height)
    .background(Palette(scheme: colorScheme).settingsWindow)
  }
}

struct SettingsGroup<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme

  let title: LocalizedStringKey
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        .padding(.leading, 4)
      VStack(spacing: 0) { content }
        .background(
          Palette(scheme: colorScheme).group,
          in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
  }
}

struct SettingsRow<Trailing: View>: View {
  let title: LocalizedStringKey
  @ViewBuilder let trailing: Trailing

  var body: some View {
    HStack(spacing: 12) {
      Text(title)
        .font(.system(size: 13))
        .foregroundStyle(Color(nsColor: .labelColor))
      Spacer(minLength: 8)
      trailing
    }
    .padding(.horizontal, 12)
    .frame(minHeight: 44)
  }
}

struct RowDivider: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Rectangle()
      .fill(Palette(scheme: colorScheme).divider)
      .frame(height: 1)
      .padding(.horizontal, 12)
  }
}

struct KeysSettings: View {
  let model: SettingsModel
  @Bindable private var preferences: Preferences

  init(model: SettingsModel) {
    self.model = model
    preferences = model.preferences
  }

  var body: some View {
    SummonKeyRow()
    RowDivider()
    SettingsRow(title: "Capture gesture") {
      HStack(spacing: 8) {
        if preferences.captureMethod == .shortcut {
          ShortcutRecorder(for: .capture).frame(width: 130)
        }
        MethodPicker(selection: $preferences.captureMethod).frame(width: 160)
      }
    }
  }
}

struct SummonKeyRow: View {
  var body: some View {
    SettingsRow(title: "Summon key") {
      ShortcutRecorder(for: .summon).fixedSize()
    }
  }
}

struct SavingSettings: View {
  let model: SettingsModel

  var body: some View {
    OffersSettings(model: model)
    RowDivider()
    WatchedFoldersSection(model: model)
    RowDivider()
    SoundSetting(preferences: model.preferences)
    RowDivider()
    StorageSection(model: model)
  }
}

private struct OffersSettings: View {
  let model: SettingsModel
  @Bindable private var preferences: Preferences

  init(model: SettingsModel) {
    self.model = model
    preferences = model.preferences
  }

  private var explanation: LocalizedStringKey {
    switch model.clipboardAccess {
    case .alwaysAllow:
      "A small offer appears when you copy an image."
    case .alwaysDeny:
      "A small offer appears when you copy an image. It shows no preview because Thoughts is set to Deny in System Settings under Privacy & Security, Paste from Other Apps."
    default:
      "A small offer appears when you copy an image. It shows a preview only if Thoughts may paste from other apps: choose Allow Paste when macOS asks, or set Thoughts to Allow in System Settings under Privacy & Security, Paste from Other Apps."
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Offer to keep copied images")
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .labelColor))
          Text(explanation)
            .font(.system(size: 12))
            .lineSpacing(2)
            .foregroundStyle(Color.helpGray)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
        Toggle("Offer to keep copied images", isOn: $preferences.offersEnabled)
          .labelsHidden()
          .toggleStyle(.switch)
      }
      .padding(.horizontal, 12)
      .padding(.top, 12)
      .padding(.bottom, 8)
      ClipboardAccessRow(model: model)
    }
  }
}

private struct SoundSetting: View {
  @Bindable var preferences: Preferences

  var body: some View {
    SettingsRow(title: "Play a sound when a thought is saved") {
      Toggle("Play a sound when a thought is saved", isOn: $preferences.soundEnabled)
        .labelsHidden()
        .toggleStyle(.switch)
    }
  }
}

struct PanelSettings: View {
  let model: SettingsModel
  @Bindable private var preferences: Preferences

  init(model: SettingsModel) {
    self.model = model
    preferences = model.preferences
  }

  var body: some View {
    MenuBarIconSetting(preferences: preferences)
    RowDivider()
    SettingsRow(title: "Open at login") {
      Toggle(
        "Open at login",
        isOn: Binding(get: { model.loginIsOn }, set: { model.setLogin($0) })
      )
      .labelsHidden()
      .toggleStyle(.switch)
    }
    if model.loginStatus == .requiresApproval {
      LoginApprovalRow(model: model)
    }
    if let error = model.loginError {
      Text(verbatim: error)
        .font(.system(size: 11))
        .foregroundStyle(Color(nsColor: .systemOrange))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
  }
}

struct MenuBarIconSetting: View {
  @Bindable var preferences: Preferences

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Show Thoughts in the menu bar")
          .font(.system(size: 13))
          .foregroundStyle(Color(nsColor: .labelColor))
        Text(verbatim: MenuBarCopy.settingsExplanation(iconShown: preferences.showsMenuBarIcon))
          .font(.system(size: 12))
          .lineSpacing(2)
          .foregroundStyle(Color.helpGray)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
      Toggle("Show Thoughts in the menu bar", isOn: $preferences.showsMenuBarIcon)
        .labelsHidden()
        .toggleStyle(.switch)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
  }
}

private struct LoginApprovalRow: View {
  let model: SettingsModel

  var body: some View {
    HStack(spacing: 12) {
      Text("macOS needs your approval before Thoughts can open at login.")
        .font(.system(size: 12))
        .foregroundStyle(Color.helpGray)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      Button("Open Login Items") { model.openLoginSettings() }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 10)
  }
}

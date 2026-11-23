import SwiftUI

struct WatchedFoldersSection: View {
  let model: SettingsModel
  @Bindable private var preferences: Preferences
  @Environment(\.colorScheme) private var colorScheme

  init(model: SettingsModel) {
    self.model = model
    preferences = model.preferences
  }

  private var palette: Palette { Palette(scheme: colorScheme) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Watched folders")
        .font(.system(size: 13))
        .foregroundStyle(Color(nsColor: .labelColor))
      Text("New images saved in these folders get the same offer.")
        .font(.system(size: 12))
        .foregroundStyle(Color.helpGray)
        .padding(.top, 2)
      VStack(spacing: 0) {
        FolderRow(
          text: PathText.abbreviated(model.screenshotFolder, home: model.home), fixed: true,
          selected: false)
        ForEach(preferences.watchedFolders, id: \.self) { folder in
          FolderRow(
            text: PathText.abbreviated(folder, home: model.home), fixed: false,
            selected: model.selectedFolder.map { SettingsModel.same($0, folder) } ?? false
          )
          .onTapGesture { model.selectedFolder = folder }
        }
        Rectangle().fill(palette.divider).frame(height: 1)
        HStack(spacing: 0) {
          Button {
            Task { await model.addWatchedFolder() }
          } label: {
            Image(systemName: "plus").frame(width: 24, height: 22)
          }
          .accessibilityLabel("Add folder")
          Rectangle().fill(palette.divider).frame(width: 1, height: 22)
          Button {
            model.removeSelectedFolder()
          } label: {
            Image(systemName: "minus").frame(width: 24, height: 22)
          }
          .disabled(model.removableSelection == nil)
          .accessibilityLabel("Remove folder")
          Rectangle().fill(palette.divider).frame(width: 1, height: 22)
          Spacer(minLength: 0)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
      }
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .strokeBorder(palette.divider, lineWidth: 1)
      }
      .padding(.top, 10)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .disabled(!preferences.offersEnabled)
    .opacity(preferences.offersEnabled ? 1 : 0.5)
  }
}

private struct FolderRow: View {
  @Environment(\.colorScheme) private var colorScheme

  let text: String
  let fixed: Bool
  let selected: Bool

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "folder.fill").foregroundStyle(Color(nsColor: .systemGray))
      Text(verbatim: text)
        .foregroundStyle(Color(nsColor: .labelColor))
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 8)
      if fixed {
        Text("Screenshot location")
          .font(.system(size: 11))
          .foregroundStyle(Color.helpGray)
      }
    }
    .font(.system(size: 13))
    .padding(.horizontal, 10)
    .frame(height: 26)
    .background(selected ? Palette(scheme: colorScheme).selection : .clear)
    .contentShape(Rectangle())
  }
}

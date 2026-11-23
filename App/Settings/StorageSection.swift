import SwiftUI

struct StorageSection: View {
  let model: SettingsModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SettingsRow(title: "Storage folder") {
        HStack(spacing: 8) {
          Button {
            model.showStorageInFinder()
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "folder.fill").foregroundStyle(Color(nsColor: .systemGray))
              Text(verbatim: model.storageText)
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .lineLimit(1)
                .truncationMode(.middle)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          Button("Change…") { Task { await model.moveStorage() } }
            .disabled(model.isMoving)
        }
      }
      if let error = model.storageError {
        Text(verbatim: error)
          .font(.system(size: 11))
          .foregroundStyle(Color(nsColor: .systemOrange))
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 12)
          .padding(.bottom, 10)
      }
    }
  }
}

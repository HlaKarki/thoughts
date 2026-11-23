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
              Image(
                systemName: model.storageMissing ? "exclamationmark.triangle.fill" : "folder.fill"
              )
              .foregroundStyle(
                model.storageMissing ? Color(nsColor: .systemOrange) : Color(nsColor: .systemGray))
              VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: model.storageText)
                  .font(.system(size: 13))
                  .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                  .lineLimit(1)
                  .truncationMode(.middle)
                if model.storageMissing {
                  Text("Thoughts can't find this folder. Use Change… to point to it.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          Button("Change…") { Task { await model.moveStorage() } }
            .disabled(model.isMoving)
        }
        .frame(height: 44)
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

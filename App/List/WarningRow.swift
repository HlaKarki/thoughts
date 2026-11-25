import SwiftUI

struct WarningRow: View {
  let fileName: String
  let reason: String
  let time: String
  let selected: Bool
  var hovered = false

  var body: some View {
    RowFrame(time: time, selected: selected, hovered: hovered) {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 12))
          .foregroundStyle(Color(nsColor: .systemOrange))
          .frame(width: 14, height: 18)
        VStack(alignment: .leading, spacing: 0) {
          Text("Can't read this thought")
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .labelColor))
            .frame(minHeight: 18, alignment: .leading)
          Text("\(fileName) is left as it is")
            .font(.system(size: 11))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(minHeight: 16, alignment: .leading)
        }
      }
    }
    .help(reason)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      Text(
        verbatim: [
          String(localized: "Can't read this thought"), fileName, reason, time,
        ].joined(separator: ", ")))
  }
}

import AppKit
import SwiftUI
import ThoughtsCore

struct Palette {
  let scheme: ColorScheme

  var isDark: Bool { scheme == .dark }
  var settingsWindow: Color { isDark ? Color(white: 0.118) : Color(white: 0.949) }
  var group: Color { isDark ? Color(white: 0.165) : .white }
  var divider: Color { isDark ? Color(white: 0.2) : Color(white: 0.933) }
  var note: Color { isDark ? Color(white: 0.18) : Color(white: 0.961) }
  var selection: Color { isDark ? Color(white: 0.212) : Color(white: 0.929) }
}

extension EnvironmentValues {
  var palette: Palette { Palette(scheme: colorScheme) }
}

struct InfoNote: View {
  @Environment(\.colorScheme) private var colorScheme

  let text: LocalizedStringKey

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "info.circle")
        .font(.system(size: 13))
        .foregroundStyle(Color(nsColor: .systemGray))
        .padding(.top, 1)
      Text(text)
        .font(.system(size: 12))
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      Palette(scheme: colorScheme).note, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

extension Modifier {
  var twiceTitle: LocalizedStringKey {
    switch self {
    case .shift: "Press Shift twice"
    case .option: "Press Option twice"
    case .control: "Press Control twice"
    case .command: "Press Command twice"
    }
  }
}

extension Modifier {
  var symbolName: String {
    switch self {
    case .shift: "shift"
    case .option: "option"
    case .control: "control"
    case .command: "command"
    }
  }
}

extension Color {
  static let helpGray = Color(white: 0.541)
}

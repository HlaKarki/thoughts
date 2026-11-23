import Foundation

enum ThoughtsURL: Equatable {
  case add(text: String)
  case addImage(path: String, note: String)
  case show
  case importInbox

  init?(_ url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.path.isEmpty || components.path == "/"
    else { return nil }
    let query = components.queryItems ?? []
    func value(_ name: String) -> String? {
      query.first { $0.name == name }?.value
    }
    switch components.host?.lowercased() {
    case "add":
      if let image = value("image"), !image.isEmpty {
        let note = value("note")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self = .addImage(path: image, note: note)
        return
      }
      let text = value("text")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard !text.isEmpty else { return nil }
      self = .add(text: text)
    case "show":
      self = .show
    case "import":
      self = .importInbox
    default:
      return nil
    }
  }
}

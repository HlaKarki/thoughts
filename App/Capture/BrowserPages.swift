import Foundation

enum BrowserPages {
  static func url(webArea: Any?, document: Any?) -> URL? {
    for candidate in [webArea, document] {
      if let url = pageURL(candidate) { return url }
    }
    return nil
  }

  static func title(_ value: Any?) -> String? {
    guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
      !text.isEmpty
    else { return nil }
    return text
  }

  private static func pageURL(_ value: Any?) -> URL? {
    let url: URL?
    switch value {
    case let value as URL: url = value
    case let value as String: url = URL(string: value.trimmingCharacters(in: .whitespaces))
    default: url = nil
    }
    guard let url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
      url.host != nil
    else { return nil }
    return url
  }
}

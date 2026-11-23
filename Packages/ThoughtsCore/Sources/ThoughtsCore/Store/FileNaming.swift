import Foundation

enum FileNaming {
  static func baseName(created: Date, id: ThoughtID, calendar: Calendar = .current) -> String {
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = calendar.timeZone
    let parts = gregorian.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: created)
    return String(
      format: "%04d%02d%02d-%02d%02d%02d-%@",
      parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!, parts.second!,
      id.rawValue)
  }
}

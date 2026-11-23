import Foundation

public enum RowTime {
  public static func label(for date: Date, now: Date, calendar: Calendar, locale: Locale) -> String
  {
    let days = calendar.dateComponents(
      [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
    ).day!
    if days == 0 {
      return format(date, calendar, locale) {
        $0.dateStyle = .none
        $0.timeStyle = .short
      }
    }
    if (1...6).contains(days) {
      return format(date, calendar, locale) { $0.setLocalizedDateFormatFromTemplate("EEE") }
    }
    let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
    let template = sameYear ? "MMMd" : "yMMMd"
    return format(date, calendar, locale) { $0.setLocalizedDateFormatFromTemplate(template) }
  }

  private static func format(
    _ date: Date, _ calendar: Calendar, _ locale: Locale,
    configure: (DateFormatter) -> Void
  ) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = locale
    configure(formatter)
    return formatter.string(from: date)
  }
}

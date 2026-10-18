import Foundation

/// Seri kartındaki son 7 gün (bugün sonda). RN: modules/gamification/weekDays.ts
struct WeekDay: Equatable, Sendable {
  let label: String
  let isToday: Bool
  let count: Int
  var full: Bool { count >= 5 }
  var partial: Bool { count > 0 && count < 5 }

  /// - Parameter dayNames: Pazartesi ile başlayan kısa gün adları (`common.weekdaysShort`).
  static func build(daily: JSONValue?, dayNames: [String], now: Date = Date()) -> [WeekDay] {
    let cal = Calendar.current
    var counts: [Date: Int] = [:]
    if case .array(let rows)? = daily {
      for row in rows {
        guard let raw = row["date"]?.stringValue, let day = localDay(raw) else { continue }
        counts[day] = row["prayer_count"]?.intValue ?? 0
      }
    }
    let today = cal.startOfDay(for: now)
    return (0..<7).map { i in
      let d = cal.date(byAdding: .day, value: i - 6, to: today)!
      // Calendar.weekday: 1 = Pazar … 7 = Cumartesi; liste Pazartesi ile başlıyor.
      let weekday = cal.component(.weekday, from: d)
      let index = weekday == 1 ? 6 : weekday - 2
      return WeekDay(
        label: dayNames.indices.contains(index) ? dayNames[index] : "",
        isToday: i == 6,
        count: counts[d] ?? 0
      )
    }
  }

  /// Backend tarihi ISO zaman damgası ("…T21:00:00.000Z") ya da yalnız gün ("2026-10-18")
  /// olabilir; JS'deki `new Date(date)` gibi yorumlanıp yerel güne çevrilir.
  private static func localDay(_ raw: String) -> Date? {
    var instant = ISO8601DateFormatter.withFractionalSeconds.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    if instant == nil {
      let f = ISO8601DateFormatter()
      f.formatOptions = [.withFullDate]
      instant = f.date(from: raw)
    }
    return instant.map { Calendar.current.startOfDay(for: $0) }
  }
}

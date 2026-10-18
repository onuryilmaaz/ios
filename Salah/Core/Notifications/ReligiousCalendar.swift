import Foundation

struct HijriDate: Equatable, Sendable {
  var year: Int
  var month: Int
  var day: Int
}

/// RN utils/hijri.ts ile aynı tabular hesap. Diyanet düzeltmesi burada değil.
enum HijriMath {
  static var gregorianCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    return calendar
  }
  static func julian(_ year: Int, _ month: Int, _ day: Int) -> Int {
    1948440 + 354 * (year - 1) + (11 * (year - 1) + 3) / 30 + (month - 1) * 29 + month / 2 + day - 1
  }

  static func hijri(_ jdn: Int) -> HijriDate {
    var year = max(1, Int(floor(Double(jdn - 1948440) / 354.37)) + 1)
    while julian(year + 1, 1, 1) <= jdn { year += 1 }
    while julian(year, 1, 1) > jdn { year -= 1 }
    var rest = jdn - julian(year, 1, 1), month = 1
    func length(_ m: Int) -> Int {
      if m % 2 == 1 { return 30 }
      return m == 12 && [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29].contains(year % 30) ? 30 : 29
    }
    while month < 12 && rest >= length(month) { rest -= length(month); month += 1 }
    return .init(year: year, month: month, day: rest + 1)
  }

  static func julian(date: Date, calendar: Calendar = gregorianCalendar) -> Int {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    let a = (14 - c.month!) / 12, y = c.year! + 4800 - a, m = c.month! + 12 * a - 3
    return c.day! + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
  }

  static func date(_ jdn: Int, calendar: Calendar = gregorianCalendar) -> Date {
    let a = jdn + 32044, b = (4 * a + 3) / 146097
    let c = a - 146097 * b / 4, d = (4 * c + 3) / 1461
    let e = c - 1461 * d / 4, m = (5 * e + 2) / 153
    return calendar.date(from: DateComponents(year: 100 * b + d - 4800 + m / 10, month: m + 3 - 12 * (m / 10), day: e - (153 * m + 2) / 5 + 1))!
  }
}

struct ReligiousDay: Equatable, Sendable {
  var id: String
  var name: String
  var date: Date
  var hijriDate: String
}

struct ReligiousCalendar {
  /// RN @salah_hijri_calendar_v1: {year,fetchedAt,days:{YYYY-MM-DD:[Y,M,D]}}.
  struct Cache: Codable {
    var year: Int
    var fetchedAt: Double
    var days: [String: [Int]]
  }
  private var diyanet: [Int: HijriDate] = [:]
  private var reverse: [String: Int] = [:]
  private var offset = 0
  var calendar: Calendar

  init(cache: Cache? = nil, calendar: Calendar = HijriMath.gregorianCalendar) {
    self.calendar = calendar
    for (iso, h) in cache?.days ?? [:] where h.count == 3 {
      guard (1...9999).contains(h[0]), (1...12).contains(h[1]), (1...30).contains(h[2]),
        let date = NotificationPlan.parseDay(iso, calendar: calendar) else { continue }
      let jdn = HijriMath.julian(date: date, calendar: calendar)
      diyanet[jdn] = .init(year: h[0], month: h[1], day: h[2])
      reverse["\(h[0])-\(h[1])-\(h[2])"] = jdn
    }
    if let last = diyanet.keys.max(), let h = diyanet[last] { offset = HijriMath.julian(h.year, h.month, h.day) - last }
  }

  func hijri(_ date: Date) -> HijriDate {
    let jdn = HijriMath.julian(date: date, calendar: calendar)
    return diyanet[jdn] ?? HijriMath.hijri(jdn + offset)
  }

  func date(year: Int, month: Int, day: Int) -> Date {
    let normalized = HijriMonth(year: year, month: month)
    let jdn = reverse["\(normalized.year)-\(normalized.month)-\(day)"] ?? (HijriMath.julian(normalized.year, normalized.month, day) - offset)
    return HijriMath.date(jdn, calendar: calendar)
  }

  func religiousDays(now: Date = Date()) -> [ReligiousDay] {
    let rules: [(String, Int, Int, Int)] = [
      ("uc_aylar", 7, 1, 0), ("mirac", 7, 26, 0), ("berat", 8, 14, 0),
      ("ramazan_arife", 9, 1, -1), ("ramazan_start", 9, 1, 0), ("kadir", 9, 26, 0),
      ("ramazan_bayram_arife", 10, 1, -1), ("ramazan_bayram_1", 10, 1, 0),
      ("ramazan_bayram_2", 10, 2, 0), ("ramazan_bayram_3", 10, 3, 0),
      ("kurban_bayram_arife", 12, 9, 0), ("kurban_bayram_1", 12, 10, 0),
      ("kurban_bayram_2", 12, 11, 0), ("kurban_bayram_3", 12, 12, 0), ("kurban_bayram_4", 12, 13, 0),
      ("hicri_yilbasi", 1, 1, 0), ("asure", 1, 10, 0), ("mevlid", 3, 12, -1),
    ]
    let current = hijri(now).year
    var result: [ReligiousDay] = []
    func make(_ id: String, _ year: Int, _ date: Date) -> ReligiousDay {
      let h = hijri(date)
      let months = Localizer.shared.list("hijri.months")
      let month = months.indices.contains(h.month - 1) ? months[h.month - 1] : ""
      return .init(id: "\(id)_\(year)", name: t("religiousDays.\(id)"), date: date, hijriDate: "\(h.day) \(month) \(h.year)")
    }
    for year in (current - 1)...(current + 1) {
      for (id, month, day, shift) in rules {
        let base = date(year: year, month: month, day: day)
        result.append(make(id, year, calendar.date(byAdding: .day, value: shift, to: base)!))
      }
      var friday = date(year: year, month: 7, day: 1)
      while calendar.component(.weekday, from: friday) != 6 { friday = calendar.date(byAdding: .day, value: 1, to: friday)! }
      result.append(make("regaib", year, calendar.date(byAdding: .day, value: -1, to: friday)!))
    }
    return result.sorted { $0.date < $1.date }
  }
}

enum ReligiousCalendarService {
  private static let key = "@salah_hijri_calendar_v1"
  static func cached() -> ReligiousCalendar { ReligiousCalendar(cache: LocalStore.decode(ReligiousCalendar.Cache.self, key)) }
  static func load(now: Date = Date()) async -> ReligiousCalendar {
    let cache = LocalStore.decode(ReligiousCalendar.Cache.self, key)
    guard !DebugLaunch.isIsolated else { return ReligiousCalendar(cache: cache) }
    let year = HijriMath.gregorianCalendar.component(.year, from: now)
    if let cache, cache.year == year, now.timeIntervalSince1970 * 1000 - cache.fetchedAt < 30 * 24 * 3600 * 1000 {
      return ReligiousCalendar(cache: cache)
    }
    struct Response: Decodable {
      struct Day: Decodable { let date: String; let hijri_date: H? }
      struct H: Decodable { let year: Int; let month: Int; let day: Int }
      let success: Bool
      let data: [Day]
    }
    let url = URL(string: "https://ezanvakti.imsakiyem.com/api/prayer-times/9654/yearly")!
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    if let (data, response) = try? await URLSession.shared.data(for: request),
      (response as? HTTPURLResponse)?.statusCode == 200,
      let result = try? JSONDecoder().decode(Response.self, from: data), result.success
    {
      var days: [String: [Int]] = [:]
      for d in result.data {
        if let h = d.hijri_date { days[String(d.date.prefix(10))] = [h.year, h.month, h.day] }
      }
      if !days.isEmpty {
        let fresh = ReligiousCalendar.Cache(year: year, fetchedAt: now.timeIntervalSince1970 * 1000, days: days)
        LocalStore.encode(fresh, for: key)
        return ReligiousCalendar(cache: fresh)
      }
    }
    return ReligiousCalendar(cache: cache)
  }
}

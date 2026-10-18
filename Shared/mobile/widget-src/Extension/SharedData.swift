import Foundation

let appGroupID = "group.com.onur6541.salah.shared"

struct WidgetData: Codable {
  var prayerName: String
  var prayerTime: String
  var nextPrayer: String
  var endTimeMs: Double
  var imsak: String
  var gunes: String
  var ogle: String
  var ikindi: String
  var aksam: String
  var yatsi: String

  static func load() -> WidgetData? {
    guard
      let ud = UserDefaults(suiteName: appGroupID),
      let data = ud.data(forKey: "salah_widget_data"),
      let obj = try? JSONDecoder().decode(WidgetData.self, from: data)
    else { return nil }
    return obj
  }
}

struct TrackerData: Codable {
  var completedPrayers: [String]
  var kazaPrayers: [String]
  var date: String

  /// Bugünün namaz gününe ait takip verisi. Namaz günü İmsak'ta başlar: gece
  /// yarısından İmsak'a kadar dünün kayıtları (ör. kılınan yatsı) geçerlidir.
  /// Uygulama yeni güne geçince önceki günü "_prev" anahtarında saklar.
  static func load() -> TrackerData? {
    guard let ud = UserDefaults(suiteName: appGroupID) else { return nil }
    let key = prayerDayKey(imsak: WidgetData.load()?.imsak)
    for storageKey in ["salah_tracker_data", "salah_tracker_data_prev"] {
      if let data = ud.data(forKey: storageKey),
         let obj = try? JSONDecoder().decode(TrackerData.self, from: data),
         obj.date == key {
        return obj
      }
    }
    return nil
  }
}

struct AmelData: Codable {
  var types: [String]
  var totalCount: Int
  var date: String

  static func load() -> AmelData? {
    guard
      let ud = UserDefaults(suiteName: appGroupID),
      let data = ud.data(forKey: "salah_amel_data"),
      let obj = try? JSONDecoder().decode(AmelData.self, from: data)
    else { return nil }
    guard obj.date == todayDateString() else { return nil }
    return obj
  }
}

struct InspirationData: Codable {
  var text: String
  var source: String
  var type: String
  var arabic: String
  var date: String

  /// Uygulamanın son yazdığı içerik (tarih kontrolü çağırana kalır).
  static func loadRaw() -> InspirationData? {
    guard
      let ud = UserDefaults(suiteName: appGroupID),
      let data = ud.data(forKey: "salah_inspiration_data"),
      let obj = try? JSONDecoder().decode(InspirationData.self, from: data)
    else { return nil }
    return obj
  }
}

/// Uygulamanın önceden yazdığı günlük ayetler (widgetVerses.ts).
struct InspirationVerse: Codable {
  var date: String
  var text: String
  var source: String
  var arabic: String

  var asInspiration: InspirationData {
    InspirationData(text: text, source: source, type: "ayet", arabic: arabic, date: date)
  }

  static func loadAll() -> [InspirationVerse] {
    guard
      let ud = UserDefaults(suiteName: appGroupID),
      let data = ud.data(forKey: "salah_inspiration_verses"),
      let list = try? JSONDecoder().decode([InspirationVerse].self, from: data)
    else { return [] }
    return list.sorted { $0.date < $1.date }
  }

  /// O günün ayeti; yoksa (liste tükendiyse) en yakın önceki, o da yoksa ilki.
  /// Boş "Yükleniyor" yerine her zaman bir ayet gösterilir.
  static func pick(for day: String, in list: [InspirationVerse]) -> InspirationVerse? {
    if let exact = list.first(where: { $0.date == day }) { return exact }
    return list.last(where: { $0.date < day }) ?? list.first
  }
}

// MARK: - Date Helpers

private func todayDateString() -> String { dayKey(Date()) }

/// Yerel takvim günü ("yyyy-MM-dd").
func dayKey(_ date: Date) -> String {
  let f = DateFormatter()
  f.calendar = Calendar(identifier: .gregorian)
  f.locale = Locale(identifier: "en_US_POSIX")
  f.dateFormat = "yyyy-MM-dd"
  return f.string(from: date)
}

/// Namaz gününün tarihi ("yyyy-MM-dd"): İmsak'tan önceyse bir önceki gün.
func prayerDayKey(now: Date = Date(), imsak: String?) -> String {
  let cal = Calendar.current
  var day = now
  let parts = (imsak ?? "").split(separator: ":").compactMap { Int($0) }
  if parts.count >= 2 {
    let c = cal.dateComponents([.hour, .minute], from: now)
    if (c.hour ?? 0) * 60 + (c.minute ?? 0) < parts[0] * 60 + parts[1] {
      day = cal.date(byAdding: .day, value: -1, to: now) ?? now
    }
  }
  let f = DateFormatter()
  f.dateFormat = "yyyy-MM-dd"
  return f.string(from: day)
}

// MARK: - Dynamic Prayer Computation

// MARK: - Prayer ID Mapping (Widget ↔ Backend)
// Backend uses: fajr, dhuhr, asr, maghrib, isha
// Widget uses:  sabah, ogle, ikindi, aksam, yatsi

let widgetToBackendPrayerID: [String: String] = [
  "sabah":  "fajr",
  "ogle":   "dhuhr",
  "ikindi": "asr",
  "aksam":  "maghrib",
  "yatsi":  "isha",
]

let backendToWidgetPrayerID: [String: String] = [
  "fajr":    "sabah",
  "dhuhr":   "ogle",
  "asr":     "ikindi",
  "maghrib": "aksam",
  "isha":    "yatsi",
]

/// Check if a backend prayer ID is in the completed list (handles both id formats)
func isPrayerCompleted(_ widgetId: String, in completedPrayers: [String]) -> Bool {
  let backendId = widgetToBackendPrayerID[widgetId] ?? widgetId
  return completedPrayers.contains(widgetId) || completedPrayers.contains(backendId)
}

/// Check if a backend prayer ID is in the kaza list (handles both id formats)
func isPrayerKaza(_ widgetId: String, in kazaPrayers: [String]) -> Bool {
  let backendId = widgetToBackendPrayerID[widgetId] ?? widgetId
  return kazaPrayers.contains(widgetId) || kazaPrayers.contains(backendId)
}

// MARK: - Alarmlar (uygulama SalahAlarmModule.swift ile yazar)

/// Kurulu alarm saatleri (App Group); `after` anından sonraki ilk alarm.
func nextAlarmDate(after date: Date) -> Date? {
  let raw = UserDefaults(suiteName: appGroupID)?.array(forKey: "salah_alarm_dates") as? [Double] ?? []
  return raw.map { Date(timeIntervalSince1970: $0) }.filter { $0 > date }.min()
}

/// Önümüzdeki 24 saatteki alarm anları (widget timeline'ı bu anlarda yenilensin).
func alarmDates(within interval: TimeInterval, from date: Date) -> [Date] {
  let raw = UserDefaults(suiteName: appGroupID)?.array(forKey: "salah_alarm_dates") as? [Double] ?? []
  return raw.map { Date(timeIntervalSince1970: $0) }.filter { $0 > date && $0 <= date.addingTimeInterval(interval) }
}

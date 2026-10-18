import Foundation

/// Bir günün vakitleri ("HH:mm", yerel saat).
struct PrayerTimes: Codable, Equatable, Sendable {
  var imsak: String
  var gunes: String
  var ogle: String
  var ikindi: String
  var aksam: String
  var yatsi: String

  subscript(key: String) -> String? {
    switch key {
    case "imsak": imsak
    case "gunes": gunes
    case "ogle": ogle
    case "ikindi": ikindi
    case "aksam": aksam
    case "yatsi": yatsi
    default: nil
    }
  }
}

/// ezanvakti API'sinin gün kaydı (yalnız kullanılan alanlar).
struct PrayerDay: Codable, Equatable, Sendable {
  /// ISO tarih, ör. "2026-07-01T00:00:00.000Z".
  var date: String
  var times: PrayerTimes
  /// Hicri tarih (yalnız ay kullanılır: Ramazan = 9, sahur alarmı için).
  var hijri_date: Hijri?

  struct Hijri: Codable, Equatable, Sendable {
    var month: Int?

    init(month: Int?) { self.month = month }

    /// Biçim beklenmedik gelirse (ör. metin) alan boş kalır; kayıt yine okunur.
    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      month = (try? c.decodeIfPresent(JSONValue.self, forKey: .month))?.flatMap(\.intValue)
    }
  }

  init(date: String, times: PrayerTimes, hijri_date: Hijri? = nil) {
    self.date = date
    self.times = times
    self.hijri_date = hijri_date
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    date = try c.decode(String.self, forKey: .date)
    times = try c.decode(PrayerTimes.self, forKey: .times)
    hijri_date = try? c.decodeIfPresent(Hijri.self, forKey: .hijri_date)
  }

  /// Kaydın ait olduğu yerel günün başlangıcı. API tarihi UTC gece yarısı
  /// verir; RN'deki `new Date(date).setHours(0,0,0,0)` ile aynı sonuç.
  var localDay: Date? {
    guard let instant = Self.parse(date) else { return nil }
    return Calendar.current.startOfDay(for: instant)
  }

  private static func parse(_ s: String) -> Date? {
    if let d = ISO8601DateFormatter.withFractionalSeconds.date(from: s) { return d }
    return ISO8601DateFormatter().date(from: s)
  }
}

/// "HH:mm" saatini verilen günün (gün kaydırmalı) anına çevirir.
func timeOn(_ hhmm: String, _ base: Date, dayOffset: Int = 0) -> Date {
  let parts = hhmm.split(separator: ":").compactMap { Int($0) }
  let cal = Calendar.current
  let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: base)) ?? base
  return cal.date(bySettingHour: parts.first ?? 0, minute: parts.count > 1 ? parts[1] : 0, second: 0, of: day) ?? day
}

/// "HH:mm"
func formatHHMM(_ date: Date) -> String {
  let c = Calendar.current.dateComponents([.hour, .minute], from: date)
  return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
}

/// Backend'deki islamicDateStr ile aynı: gece 04:00'dan önce hâlâ önceki İslami gün.
/// Offline kuyruğa alınan kayıtlar bu tarihle damgalanır.
func islamicDateString(_ now: Date = Date()) -> String {
  let cal = Calendar.current
  let d = cal.component(.hour, from: now) < 4 ? now.addingTimeInterval(-5 * 3600) : now
  let c = cal.dateComponents([.year, .month, .day], from: d)
  return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

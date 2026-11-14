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

/// Bugünkü bir namazın o anki durumu (ana sayfa takip kartı ve Siri "Kıldım" aynı kuralı kullanır).
enum PrayerSlotState: Equatable, Sendable {
  case upcoming, current, expired

  /// id → (vaktin anahtarı, çıkış anahtarı). Yatsının çıkışı ertesi imsaktır.
  static let keys: [String: (start: String, end: String?)] = [
    "fajr": ("imsak", "gunes"), "dhuhr": ("ogle", "ikindi"), "asr": ("ikindi", "aksam"),
    "maghrib": ("aksam", "yatsi"), "isha": ("yatsi", nil),
  ]

  /// Türkçe ad ("Öğle") → id ("dhuhr").
  static let idsByName = ["Sabah": "fajr", "Öğle": "dhuhr", "İkindi": "asr", "Akşam": "maghrib", "Yatsı": "isha"]

  static func of(_ prayerId: String, times: PrayerTimes, now: Date) -> PrayerSlotState {
    let cal = Calendar.current
    let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
    func minutes(_ hhmm: String) -> Int {
      let p = hhmm.split(separator: ":").compactMap { Int($0) }
      return (p.first ?? 0) * 60 + (p.count > 1 ? p[1] : 0)
    }
    // Gece yarısı ile imsak arası hâlâ önceki namaz günü.
    let inIslamicBridge = nowMin < minutes(times.imsak)
    // 04:00'ten sonra sunucu yeni güne geçmiş olur (islamicDateString): imsaka kadar yapılan işaret
    // bugünün henüz girmemiş vaktine yazılırdı. Bu arada hiçbir vakit işaretlenemez.
    if inIslamicBridge && nowMin >= 4 * 60 { return .upcoming }
    let key = keys[prayerId]
    let start = minutes(key.flatMap { times[$0.start] } ?? "00:00")

    if prayerId == "isha" {
      return nowMin >= start || inIslamicBridge ? .current : .upcoming
    }
    if inIslamicBridge { return .expired }
    let end = key?.end.flatMap { times[$0] }.map(minutes) ?? start + 240
    if nowMin < start { return .upcoming }
    return nowMin < end ? .current : .expired
  }
}

/// Geçmiş ekranında vakti girmemiş namazın işaretlenmesini engeller.
enum PrayerSlotGate {
  /// Kayıt id'si → vakit anahtarı.
  static let timeKeys = ["fajr": "imsak", "dhuhr": "ogle", "asr": "ikindi", "maghrib": "aksam", "isha": "yatsi"]

  /// Gelecek günde her vakit kapalıdır; bugünde vakit girene kadar kapalıdır.
  /// Geçmiş günlerde ya da vakit bilinmiyorsa (önbellek boş) açık bırakılır.
  static func notYet(_ prayerId: String, day: Date, now: Date, times: PrayerTimes?) -> Bool {
    let cal = Calendar.current
    let d = cal.startOfDay(for: day)
    let today = cal.startOfDay(for: now)
    if d > today { return true }
    guard d == today, let key = timeKeys[prayerId], let hhmm = times?[key] else { return false }
    return now < timeOn(hhmm, now)
  }
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

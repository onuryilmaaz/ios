import Foundation

/// Alarm planı: ayarlar + günlük vakitler → kurulacak alarmlar. Saf fonksiyonlar.
/// RN: modules/alarm/alarm.plan.ts (aynı kurallar, aynı testler).
///
/// Vakitler her gün kaydığı için AlarmKit'in haftalık tekrarı kullanılmaz;
/// her gün için ayrı, tarihli bir alarm üretilir.
nonisolated enum AlarmPlan {
  static let prayerKeys = ["imsak", "gunes", "ogle", "ikindi", "aksam", "yatsi"]
  static let tones = ["chime", "soft", "beep"]
  /// Ton → paketteki ses dosyası.
  static let toneSounds = ["chime": "tone_chime.caf", "soft": "tone_soft.caf", "beep": "tone_beep.caf"]
  /// Elle girilen dakika ayarlarının üst sınırı.
  static let maxOffsetMinutes = 180
  /// Kaç günlük alarm kurulur; uygulama açıldıkça yenilenir.
  static let planDays = 14

  struct Day: Sendable {
    /// API tarihi (ISO, UTC olabilir); yerel güne çevrilir.
    let date: String
    let times: [String: String]
    /// Hicri ay (Ramazan = 9).
    let hijriMonth: Int?
  }

  enum Planned: Equatable, Sendable {
    case prayer(fireAt: Date, key: String, offset: Int)
    case tahajjud(fireAt: Date)
    case sahur(fireAt: Date)
    case custom(fireAt: Date, id: String, label: String)

    var fireAt: Date {
      switch self {
      case .prayer(let d, _, _), .tahajjud(let d), .sahur(let d), .custom(let d, _, _): d
      }
    }
  }

  /// Gecenin son üçte birinin başı: akşamdan ertesi imsağa kadar olan gecenin 2/3'ü (dakikaya yuvarlı).
  static func lastThirdStart(maghrib: Date, nextFajr: Date) -> Date {
    let minutes = ((nextFajr.timeIntervalSince(maghrib) * 2 / 3) / 60).rounded()
    return maghrib.addingTimeInterval(minutes * 60)
  }

  /// Şimdiden sonraki ilk "saat:dakika" anı (tek seferlik alarm).
  static func nextOccurrence(hour: Int, minute: Int, now: Date, calendar: Calendar = .current) -> Date {
    let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
  }

  static func build(days: [Day], settings: AlarmSettings, now: Date, horizonDays: Int = planDays, calendar: Calendar = .current) -> [Planned] {
    let today = calendar.startOfDay(for: now)
    let horizonEnd = calendar.date(byAdding: .day, value: horizonDays, to: today)!
    var out: [Planned] = []

    let parsed = days.compactMap { d -> (day: Date, raw: Day)? in
      guard let day = localDay(d.date, calendar: calendar), day < horizonEnd else { return nil }
      return (day, d)
    }
    .sorted { $0.day < $1.day }

    // Gece yarısından sonra açıldıysa içinde bulunulan gecenin (dün akşam → bugün imsak)
    // teheccüdü için dünün akşamı bugününkinden tahmin edilir.
    if settings.tahajjud.enabled, let first = parsed.first,
      let fajr = at(first.day, first.raw.times["imsak"], calendar), let maghribToday = at(first.day, first.raw.times["aksam"], calendar)
    {
      let start = lastThirdStart(maghrib: maghribToday.addingTimeInterval(-24 * 3600), nextFajr: fajr)
      out.append(.tahajjud(fireAt: start.addingTimeInterval(Double(settings.tahajjud.offset) * 60)))
    }

    for (i, entry) in parsed.enumerated() {
      let (day, raw) = entry
      for key in prayerKeys {
        guard let s = settings.prayers[key], s.enabled, let base = at(day, raw.times[key], calendar) else { continue }
        out.append(.prayer(fireAt: base.addingTimeInterval(Double(s.offset) * 60), key: key, offset: s.offset))
      }

      if settings.tahajjud.enabled, i + 1 < parsed.count {
        let next = parsed[i + 1]
        let isNextDay = next.day.timeIntervalSince(day) < 36 * 3600
        if isNextDay, let maghrib = at(day, raw.times["aksam"], calendar), let fajr = at(next.day, next.raw.times["imsak"], calendar), fajr > maghrib {
          let start = lastThirdStart(maghrib: maghrib, nextFajr: fajr)
          out.append(.tahajjud(fireAt: start.addingTimeInterval(Double(settings.tahajjud.offset) * 60)))
        }
      }

      if settings.sahur.enabled, !settings.sahur.onlyRamadan || raw.hijriMonth == 9, let fajr = at(day, raw.times["imsak"], calendar) {
        out.append(.sahur(fireAt: fajr.addingTimeInterval(-Double(settings.sahur.minutesBefore) * 60)))
      }
    }

    for c in settings.custom where c.enabled {
      if c.days.isEmpty {
        if let once = c.onceAtDate, once > now { out.append(.custom(fireAt: once, id: c.id, label: c.label)) }
        continue
      }
      for d in 0..<horizonDays {
        guard let day = calendar.date(byAdding: .day, value: d, to: today) else { continue }
        // Calendar.weekday 1 = Pazar; RN/JS günü 0 = Pazar.
        guard c.days.contains(calendar.component(.weekday, from: day) - 1),
          let fire = calendar.date(bySettingHour: c.hour, minute: c.minute, second: 0, of: day)
        else { continue }
        out.append(.custom(fireAt: fire, id: c.id, label: c.label))
      }
    }

    return out.filter { $0.fireAt > now }.sorted { $0.fireAt < $1.fireAt }
  }

  /// Herhangi bir alarm açık mı (değilse AlarmKit'e hiç dokunmaya gerek yok).
  static func hasAnyAlarm(_ s: AlarmSettings) -> Bool {
    prayerKeys.contains { s.prayers[$0]?.enabled == true } || s.tahajjud.enabled || s.sahur.enabled || s.custom.contains(where: \.enabled)
  }

  private static func localDay(_ raw: String, calendar: Calendar) -> Date? {
    let instant = ISO8601DateFormatter.withFractionalSeconds.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) ?? {
      let f = ISO8601DateFormatter()
      f.formatOptions = [.withFullDate]
      return f.date(from: raw)
    }()
    return instant.map { calendar.startOfDay(for: $0) }
  }

  /// "HH:mm" → o günün yerel saati.
  private static func at(_ day: Date, _ hhmm: String?, _ calendar: Calendar) -> Date? {
    guard let hhmm else { return nil }
    let p = hhmm.split(separator: ":").compactMap { Int($0) }
    guard p.count >= 2 else { return nil }
    return calendar.date(bySettingHour: p[0], minute: p[1], second: 0, of: day)
  }
}

/// Alarm ayarları; RN ile aynı anahtar (`ALARM_SETTINGS_V1`) ve JSON biçimi.
nonisolated struct AlarmSettings: Codable, Equatable, Sendable {
  struct Prayer: Codable, Equatable, Sendable {
    var enabled: Bool
    /// Vakte göre dakika: negatif = önce, pozitif = sonra.
    var offset: Int
  }

  struct Tahajjud: Codable, Equatable, Sendable {
    var enabled: Bool
    /// Gecenin son üçte birinin başına göre dakika.
    var offset: Int
  }

  struct Sahur: Codable, Equatable, Sendable {
    var enabled: Bool
    var minutesBefore: Int
    var onlyRamadan: Bool
  }

  struct Custom: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var hour: Int
    var minute: Int
    /// Tekrar günleri (0 = Pazar … 6 = Cumartesi). Boşsa tek seferlik.
    var days: [Int]
    /// Tek seferlik alarmın anı (ms); tekrarlıda yok.
    var onceAt: Double?
    var label: String
    var enabled: Bool

    var onceAtDate: Date? { onceAt.map { Date(timeIntervalSince1970: $0 / 1000) } }
  }

  var prayers: [String: Prayer]
  var tahajjud: Tahajjud
  var sahur: Sahur
  var custom: [Custom]
  /// adhan | default | chime | soft | beep
  var sound: String
  /// Vakit alarmında ikinci düğme: mark (Kıldım) | snooze (Ertele).
  var secondary: String
  var snoozeMinutes: Int

  static let defaults = AlarmSettings(
    prayers: [
      "imsak": .init(enabled: false, offset: 15),
      "gunes": .init(enabled: false, offset: -30),
      "ogle": .init(enabled: false, offset: 0),
      "ikindi": .init(enabled: false, offset: 0),
      "aksam": .init(enabled: false, offset: 0),
      "yatsi": .init(enabled: false, offset: 0),
    ],
    tahajjud: .init(enabled: false, offset: 0),
    sahur: .init(enabled: false, minutesBefore: 45, onlyRamadan: true),
    custom: [],
    sound: "adhan",
    secondary: "mark",
    snoozeMinutes: 10)

  init(prayers: [String: Prayer], tahajjud: Tahajjud, sahur: Sahur, custom: [Custom], sound: String, secondary: String, snoozeMinutes: Int) {
    self.prayers = prayers
    self.tahajjud = tahajjud
    self.sahur = sahur
    self.custom = custom
    self.sound = sound
    self.secondary = secondary
    self.snoozeMinutes = snoozeMinutes
  }

  /// Eksik/eski kayıtlar varsayılanlarla tamamlanır (RN `withDefaults`).
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = Self.defaults
    var prayers = d.prayers
    for (k, v) in (try? c.decodeIfPresent([String: Prayer].self, forKey: .prayers)) ?? [:] { prayers[k] = v }
    self.prayers = prayers
    tahajjud = (try? c.decodeIfPresent(Tahajjud.self, forKey: .tahajjud)) ?? d.tahajjud
    sahur = (try? c.decodeIfPresent(Sahur.self, forKey: .sahur)) ?? d.sahur
    custom = (try? c.decodeIfPresent([Custom].self, forKey: .custom)) ?? []
    let s = (try? c.decodeIfPresent(String.self, forKey: .sound)) ?? d.sound
    sound = s == "adhan" || s == "default" || AlarmPlan.tones.contains(s) ? s : d.sound
    secondary = (try? c.decodeIfPresent(String.self, forKey: .secondary)) ?? d.secondary
    snoozeMinutes = (try? c.decodeIfPresent(Int.self, forKey: .snoozeMinutes)) ?? d.snoozeMinutes
  }
}

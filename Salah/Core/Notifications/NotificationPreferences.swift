import Foundation

/// RN AsyncStorage anahtarları ve JSON biçimleri değişmez.
struct NotificationPreferences: Equatable, Sendable {
  static let prayers = ["imsak", "gunes", "ogle", "ikindi", "aksam", "yatsi"]
  static let defaultPrayers = Dictionary(uniqueKeysWithValues: prayers.map { ($0, $0 != "gunes") })
  var enabled = false
  var offsets = [0]
  var prayerEnabled = defaultPrayers
  var adhanEnabled = defaultPrayers
  var inspiration = true
  var religiousDays = true
  var friday = true
  var muteUntil: Date?

  static func read(now: Date = Date(), get: (String) -> String? = { LocalStore.string($0) }) -> Self {
    var value = Self()
    value.enabled = get("PRAYER_NOTIFICATIONS_ENABLED") == "true"
    value.offsets = decodeOffsets(get("PRAYER_NOTIFICATION_OFFSETS"), legacy: get("PRAYER_NOTIFICATION_OFFSET"))
    value.prayerEnabled.merge(decode([String: Bool].self, get("PRAYER_NOTIFICATION_EACH")) ?? [:]) { _, new in new }
    value.adhanEnabled.merge(decode([String: Bool].self, get("ADHAN_PRAYERS_V2")) ?? [:]) { _, new in new }
    value.inspiration = get("REMINDER_ENABLED").map { $0 == "true" } ?? true
    value.religiousDays = get("RELIGIOUS_DAY_NOTIFICATIONS_ENABLED").map { $0 == "true" } ?? true
    value.friday = get("CUMA_REMINDER_ENABLED").map { $0 == "true" } ?? true
    if let raw = get("NOTIFICATION_MUTE_UNTIL"), let ms = Double(raw), ms.isFinite {
      let date = Date(timeIntervalSince1970: ms / 1000)
      if date > now { value.muteUntil = date }
    }
    return value
  }

  static func decodeOffsets(_ raw: String?, legacy: String?) -> [Int] {
    if let values = decode([JSONValue].self, raw) {
      let nums = values.compactMap { value -> Double? in
        if case .number(let number) = value { return number }
        return nil
      }
      let safe = nums.filter { $0.isFinite && $0 >= 0 && $0 <= 1440 && $0.rounded() == $0 }.map(Int.init)
      return safe.isEmpty ? [0] : Array(Set(safe)).sorted()
    }
    if let legacy, let n = Int(legacy), n > 0, n <= 1440 { return [0, n] }
    return [0]
  }

  private static func decode<T: Decodable>(_ type: T.Type, _ raw: String?) -> T? {
    raw.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode(type, from: $0) }
  }

  func isMuted(at date: Date = Date()) -> Bool { muteUntil.map { $0 > date } ?? false }
}

func muteRemaining(_ until: Date, now: Date = Date()) -> String {
  let minutes = max(0, Int(ceil(until.timeIntervalSince(now) / 60)))
  if minutes == 0 { return t("mute.ended") }
  if minutes < 60 { return t("mute.minutes", ["count": minutes]) }
  let hours = minutes / 60, rest = minutes % 60
  return rest == 0 ? t("mute.hours", ["count": hours]) : t("mute.hoursMinutes", ["h": hours, "m": rest])
}

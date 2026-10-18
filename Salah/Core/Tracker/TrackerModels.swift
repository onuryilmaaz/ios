import Foundation

/// İbadet türleri; sıra RN'deki ACTIVITY_META ile aynı. Metinler `activities.<tür>.*`.
enum ActivityType: String, Codable, CaseIterable, Sendable {
  case quran, nafile, fasting, sadaka, dua, memorization, book

  var icon: String {
    switch self {
    case .quran: "book"
    case .nafile: "star"
    case .fasting: "nutrition"
    case .sadaka: "heart"
    case .dua: "hand-left"
    case .memorization: "library"
    case .book: "library-outline"
    }
  }

  var label: String { t("activities.\(rawValue).label") }
  var descriptionText: String { t("activities.\(rawValue).description") }
  var unit: String { t("activities.\(rawValue).unit") }
}

struct TrackerLog: Codable, Equatable, Identifiable, Sendable {
  var id: String
  var date: String
  /// Kaldırılmış türlere (ör. zikir) ait eski kayıtlar için ham değer korunur.
  var activity_type: String
  var value: JSONValue
  var notes: String?
  var created_at: String?

  var type: ActivityType? { ActivityType(rawValue: activity_type) }

  enum CodingKeys: String, CodingKey { case id, date, activity_type, value, notes, created_at }

  init(id: String, date: String, activity_type: String, value: JSONValue, notes: String?, created_at: String?) {
    self.id = id
    self.date = date
    self.activity_type = activity_type
    self.value = value
    self.notes = notes
    self.created_at = created_at
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    // Sunucu id'yi sayı ya da metin döndürebilir.
    if let s = try? c.decode(String.self, forKey: .id) {
      id = s
    } else {
      id = String(try c.decode(Int.self, forKey: .id))
    }
    date = (try? c.decode(String.self, forKey: .date)) ?? ""
    activity_type = try c.decode(String.self, forKey: .activity_type)
    value = (try? c.decode(JSONValue.self, forKey: .value)) ?? .object([:])
    notes = try? c.decodeIfPresent(String.self, forKey: .notes)
    created_at = try? c.decodeIfPresent(String.self, forKey: .created_at)
  }

  /// Değer alanı sayı olarak (yoksa 0).
  func number(_ key: String) -> Double {
    switch value[key] {
    case .number(let n)?: n
    case .string(let s)?: Double(s) ?? 0
    default: 0
    }
  }

  func text(_ key: String) -> String? {
    guard let s = value[key]?.stringValue, !s.isEmpty else { return nil }
    return s
  }
}

/// Sayıyı gereksiz ".0" olmadan yazar.
func formatNumber(_ n: Double) -> String {
  n.rounded() == n ? String(Int(n)) : String(n)
}

/// Yerel takvim tarihi (YYYY-MM-DD); UTC değil (gece 00–03 arası kayma olmasın).
func localDateString(_ d: Date = Date()) -> String {
  let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
  return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

enum TrackerText {
  static let nafileTypes = [
    "sabah_sunnet", "ogle_sunnet", "ikindi_sunnet", "aksam_sunnet", "yatsi_sunnet",
    "vitir", "teheccud", "duha", "evvabin", "teravih", "diger",
  ]
  static let fastingTypes = ["nafile", "pazartesi_persembe", "kaza"]

  static func nafile(_ type: String) -> String {
    let key = "tracker.nafile.\(type)"
    let s = t(key)
    return s == key ? type : s
  }

  static func fasting(_ type: String, short: Bool = false) -> String {
    let name = type == "pazartesi_persembe" && short ? "pazartesi_persembeShort" : type
    let key = "tracker.fasting.\(name)"
    let s = t(key)
    return s == key ? type : s
  }

  /// Kayıt satırındaki değer özeti. RN: TrackerScreen `getValueLabel`.
  static func valueLabel(_ log: TrackerLog) -> String {
    guard let type = log.type else { return "" }
    let minutes = log.number("minutes")
    let mins = minutes > 0 ? " · \(t("tracker.value.minutesShort", ["count": formatNumber(minutes)]))" : ""
    let pages = t("tracker.value.pages", ["count": formatNumber(log.number("pages"))])
    switch type {
    case .quran:
      return pages + mins
    case .book:
      return (log.text("name").map { "\($0) · " } ?? "") + pages + mins
    case .nafile:
      return "\(nafile(log.text("type") ?? "")) · \(t("tracker.value.rakaat", ["count": formatNumber(log.number("rakaat"))]))"
    case .fasting:
      return fasting(log.text("type") ?? "", short: true)
    case .sadaka:
      return "\(formatNumber(log.number("amount")))\(type.unit)" + (log.text("description").map { " · \($0)" } ?? "")
    case .dua:
      return t("tracker.value.minutes", ["count": formatNumber(minutes)]) + (log.text("type").map { " · \($0)" } ?? "")
    case .memorization:
      let new = formatNumber(log.number("new_ayets"))
      let revision = log.number("revision_ayets")
      return revision > 0
        ? t("tracker.value.memorizationRevision", ["new": new, "revision": formatNumber(revision)])
        : t("tracker.value.memorization", ["new": new])
    }
  }

  /// Türün bugünkü toplamı (sayfa, rekat, dakika…). RN: `aggregateToday`.
  static func aggregate(_ logs: [TrackerLog], _ type: ActivityType) -> Double {
    let items = logs.filter { $0.type == type }
    switch type {
    case .quran, .book: return items.reduce(0) { $0 + $1.number("pages") }
    case .nafile: return items.reduce(0) { $0 + $1.number("rakaat") }
    case .fasting: return Double(items.count)
    case .sadaka: return items.reduce(0) { $0 + $1.number("amount") }
    case .dua: return items.reduce(0) { $0 + $1.number("minutes") }
    case .memorization: return items.reduce(0) { $0 + $1.number("new_ayets") + $1.number("revision_ayets") }
    }
  }
}

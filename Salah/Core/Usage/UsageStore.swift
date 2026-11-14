import Foundation

/// Kimliksiz kullanım sayaçları: gün ve olay başına toplam cihazda birikir, öne gelişte `/app/usage` ile gönderilir
/// (sunucu `usage` özelliğini destekliyorsa). Kullanıcı ya da cihaz kimliği gönderilmez. Sunucu yalnız dün, bugün ve
/// yarını kabul ettiği için daha eski günler atılır. Android `UsageStore` ile aynı olay adları.
@MainActor
final class UsageStore {
  static let shared = UsageStore()
  private static let key = "@salah_usage_v1"
  private static let maxEventsPerDay = 60

  /// gün ("yyyy-MM-dd") → olay → sayı
  private var days: [String: [String: Int]]
  private var flushing = false

  private init() {
    days = LocalStore.decode([String: [String: Int]].self, Self.key) ?? [:]
  }

  /// Olay adı: `app.open`, `tab.quran`, `screen.qibla` gibi; nokta ile en fazla üç parça.
  static func isValid(_ event: String) -> Bool {
    event.range(of: #"^[a-z][a-zA-Z0-9]{0,30}(\.[a-zA-Z0-9]{1,40}){0,2}$"#, options: .regularExpression) != nil
  }

  func record(_ event: String, now: Date = Date()) {
    guard !DebugLaunch.isIsolated, Self.isValid(event) else { return }
    let day = localDateString(now)
    var counts = days[day] ?? [:]
    guard counts[event] != nil || counts.count < Self.maxEventsPerDay else { return }
    counts[event, default: 0] += 1
    days[day] = counts
    persist()
  }

  /// Bekleyen günleri gönderir; başarıda o gün silinir, ağ hatasında kalır.
  func flush(now: Date = Date()) async {
    guard !flushing, !DebugLaunch.isIsolated, AppControlStore.shared.supports("usage") else { return }
    flushing = true
    defer { flushing = false }
    let cal = Calendar.current
    let oldest = localDateString(cal.date(byAdding: .day, value: -1, to: now) ?? now)
    for day in days.keys.sorted() where day < oldest { days[day] = nil }
    for (day, counts) in days.sorted(by: { $0.key < $1.key }) where !counts.isEmpty {
      let events = JSONValue.object(counts.mapValues { .number(Double($0)) })
      let body: JSONValue = ["platform": .string("ios"), "day": .string(day), "events": events]
      do {
        try await APIClient.shared.send("POST", "/app/usage", body: body)
        days[day] = nil
      } catch {
        // 4xx (ör. hız sınırı, geçersiz gün) tekrar denenmez; ağ/5xx'te sonraki öne gelişte denenir.
        if let status = (error as? APIError)?.status, (400..<500).contains(status), status != 429 { days[day] = nil }
        break
      }
    }
    persist()
  }

  private func persist() {
    LocalStore.encode(days, for: Self.key)
  }
}

extension HomeRoute {
  /// Kullanım sayacındaki ekran adı (ilişkili değer atılır): `screen.hatimGroup`.
  var usageName: String {
    Mirror(reflecting: self).children.first?.label ?? "\(self)"
  }
}

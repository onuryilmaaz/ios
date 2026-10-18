import Foundation

/// Vakitleri offline-first getirir. RN'deki services/prayer.service.ts ile aynı
/// kurallar ve aynı cache anahtarı (`@salah_prayer_times_cache_<ilçe>`):
/// 1. Cache taze (6 saat) ve en az 3 günü kapsıyorsa ağa çıkmaz.
/// 2. Değilse aylık (gerekirse haftalık) veriyi çekip cache ile birleştirir.
/// 3. Ağ yoksa elde ne varsa (bayat cache dahil) onu döndürür.
enum PrayerTimesService {
  static let defaultDistrictId = "9654"

  private static let baseURL = URL(string: "https://ezanvakti.imsakiyem.com/api")!
  private static let cachePrefix = "@salah_prayer_times_cache_"
  private static let freshInterval: TimeInterval = 6 * 3600
  private static let minCoverDays = 3

  private struct Cache: Codable {
    /// ms (RN biçimi)
    var fetchedAt: Double
    var days: [PrayerDay]
  }

  private struct Response: Decodable {
    var success: Bool
    var data: [PrayerDay]?
  }

  /// Bugün ve sonraki günler (en az bugün; yoksa elde ne varsa).
  static func upcomingDays(districtId: String) async -> [PrayerDay] {
    let cache = readCache(districtId)
    let cached = cache.map { fromToday($0.days) } ?? []
    if let cache, Date().timeIntervalSince1970 * 1000 - cache.fetchedAt < freshInterval * 1000,
      cached.count >= minCoverDays
    {
      return cached
    }

    // Aylık uç sunucunun (UTC) takvim ayını döndürür: ay başı/sonunda bugünü
    // kapsamayabilir, o zaman haftalıkla tamamlanır.
    var fetched = false
    for range in ["monthly", "weekly"] {
      let url = baseURL.appendingPathComponent("prayer-times/\(districtId)/\(range)")
      var request = URLRequest(url: url)
      request.timeoutInterval = 15
      guard let (data, _) = try? await URLSession.shared.data(for: request),
        let res = try? JSONDecoder().decode(Response.self, from: data),
        res.success, let days = res.data, !days.isEmpty
      else { continue }
      mergeAndSave(districtId, days)
      fetched = true
      let merged = fromToday(readCache(districtId)?.days ?? days)
      if covers(merged) { return merged }
    }
    return fetched ? fromToday(readCache(districtId)?.days ?? []) : cached
  }

  static func today(districtId: String) async -> PrayerDay? {
    let days = await upcomingDays(districtId: districtId)
    let today = Calendar.current.startOfDay(for: Date())
    return days.first { $0.localDay == today } ?? days.first
  }

  // MARK: - Cache

  private static func readCache(_ districtId: String) -> Cache? {
    LocalStore.decode(Cache.self, cachePrefix + districtId)
  }

  /// Yeni günleri eskilerle birleştirir (tarihe göre tekil, sıralı), dünden öncesini atar.
  private static func mergeAndSave(_ districtId: String, _ newDays: [PrayerDay]) {
    var byDay: [Date: PrayerDay] = [:]
    for day in (readCache(districtId)?.days ?? []) + newDays {
      if let d = day.localDay { byDay[d] = day }
    }
    let cal = Calendar.current
    let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
    let days = byDay.filter { $0.key >= yesterday }.sorted { $0.key < $1.key }.map(\.value)
    LocalStore.encode(Cache(fetchedAt: Date().timeIntervalSince1970 * 1000, days: days), for: cachePrefix + districtId)
  }

  private static func fromToday(_ days: [PrayerDay]) -> [PrayerDay] {
    let today = Calendar.current.startOfDay(for: Date())
    return days.filter { ($0.localDay ?? .distantPast) >= today }
  }

  private static func covers(_ days: [PrayerDay]) -> Bool {
    days.count >= minCoverDays && days.first?.localDay == Calendar.current.startOfDay(for: Date())
  }
}

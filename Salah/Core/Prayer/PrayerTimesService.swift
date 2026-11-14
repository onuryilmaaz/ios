import Foundation

/// Vakitleri offline-first getirir. RN'deki services/prayer.service.ts ile aynı
/// kurallar ve aynı cache anahtarı (`@salah_prayer_times_cache_<ilçe>`):
/// 1. Cache taze (6 saat) ve en az 3 günü kapsıyorsa ağa çıkmaz; 30+ gün ilerisi elindeyse 7 gün boyunca çıkmaz.
/// 2. Değilse önce yıllık (uygulama uzun süre açılmasa ya da çevrimdışı kalsa da çalışsın diye),
///    olmazsa aylık/haftalık veriyi çekip cache ile birleştirir: önce kendi sunucumuz
///    (/prayer/times), olmazsa ezanvakti.imsakiyem.com.
/// 3. Ağ yoksa elde ne varsa (bayat cache dahil) onu döndürür.
/// Yıllık veri sunucudaki veri setine bağlı (yıl sonunda bir sonraki yıl eklenene kadar 31 Aralık'ta biter);
/// bu yüzden haftada bir (önbellek azaldıysa günde bir) yeniden denenir. Android PrayerTimesService ile aynı.
enum PrayerTimesService {
  static let defaultDistrictId = "9654"

  private static let baseURL = URL(string: "https://ezanvakti.imsakiyem.com/api")!
  private static let cachePrefix = "@salah_prayer_times_cache_"
  private static let freshInterval: TimeInterval = 6 * 3600
  private static let minCoverDays = 3
  private static let longCoverDays = 30
  private static let longFreshInterval: TimeInterval = 7 * 24 * 3600
  private static let yearTargetDays = 300
  private static let yearlyAtPrefix = "@salah_prayer_times_yearly_at_"
  /// Testlerde sahte kaynak ve saat.
  static var fetcher: (String, String) async -> [PrayerDay]? = { await fetch(districtId: $0, range: $1) }
  static var now: () -> Date = { Date() }

  private struct Cache: Codable {
    /// ms (RN biçimi)
    var fetchedAt: Double
    var days: [PrayerDay]
  }

  private struct Response: Decodable {
    var success: Bool
    var data: [PrayerDay]?
  }

  /// Bugün ve sonraki günler. Elde bugünün Diyanet verisi yoksa (uzun çevrimdışı, sunucuda yeni yıl yok) ilçenin
  /// koordinatıyla cihazda hesaplanan 30 gün döner (`PrayerCalc`).
  static func upcomingDays(districtId: String) async -> [PrayerDay] {
    withFallback(await loadDays(districtId: districtId), districtId: districtId)
  }

  private static let coordsPrefix = "@salah_district_coords_v1_"
  private static let fallbackDays = 30

  /// İlçenin koordinatı (Diyanet vakitlerinden bulunmuş); yoksa nil.
  static func coordinates(_ districtId: String) -> PrayerCalc.Coordinates? {
    LocalStore.decode(PrayerCalc.Coordinates.self, coordsPrefix + districtId)
  }

  /// Önbellekte yeterli Diyanet günü varsa koordinat bir kez bulunup saklanır.
  private static func learnCoordinates(_ districtId: String, days: [PrayerDay]) {
    guard coordinates(districtId) == nil, days.count >= 20, let c = PrayerCalc.fit(days) else { return }
    LocalStore.encode(c, for: coordsPrefix + districtId)
  }

  static func withFallback(_ days: [PrayerDay], districtId: String) -> [PrayerDay] {
    let today = Calendar.current.startOfDay(for: now())
    guard days.first?.localDay != today, let c = coordinates(districtId) else { return days }
    return (0..<fallbackDays).compactMap { offset in
      Calendar.current.date(byAdding: .day, value: offset, to: today).flatMap { PrayerCalc.day($0, at: c) }
    }
  }

  private static func loadDays(districtId: String) async -> [PrayerDay] {
    let cache = readCache(districtId)
    if let cache { learnCoordinates(districtId, days: cache.days) }
    let cached = cache.map { fromToday($0.days) } ?? []
    if let cache {
      let age = now().timeIntervalSince1970 - cache.fetchedAt / 1000
      if age < freshInterval, cached.count >= minCoverDays { return cached }
      if age < longFreshInterval, cached.count >= longCoverDays, covers(cached) { return cached }
    }

    // Yıllık önce; aylık uç sunucunun (UTC) takvim ayını döndürür: ay başı/sonunda bugünü
    // kapsamayabilir, o zaman haftalıkla tamamlanır.
    let ranges = yearlyDue(districtId, coverDays: cached.count) ? ["yearly", "monthly", "weekly"] : ["monthly", "weekly"]
    var fetched = false
    for range in ranges {
      if range == "yearly" { LocalStore.set(String(now().timeIntervalSince1970), for: yearlyAtPrefix + districtId) }
      guard let days = await fetcher(districtId, range) else { continue }
      mergeAndSave(districtId, days)
      fetched = true
      let merged = fromToday(readCache(districtId)?.days ?? days)
      if covers(merged) { return merged }
    }
    return fetched ? fromToday(readCache(districtId)?.days ?? []) : cached
  }

  /// Önce kendi sunucumuz (Diyanet açık veri seti; dış servise bağımlı değil), olmazsa
  /// ezanvakti.imsakiyem.com. İkisi de aynı JSON biçimini döner.
  private static func fetch(districtId: String, range: String) async -> [PrayerDay]? {
    let sources = [
      URL(string: APIClient.shared.baseURL.absoluteString + "/prayer/times/\(districtId)/\(range)"),
      baseURL.appendingPathComponent("prayer-times/\(districtId)/\(range)"),
    ].compactMap { $0 }
    for url in sources {
      var request = URLRequest(url: url)
      request.timeoutInterval = 10
      guard let (data, response) = try? await URLSession.shared.data(for: request),
        (response as? HTTPURLResponse)?.statusCode == 200,
        let res = try? JSONDecoder().decode(Response.self, from: data),
        res.success, let days = res.data, !days.isEmpty
      else { continue }
      return days
    }
    return nil
  }

  /// Bu Ramazan'ın imsakiyesi: yıllık vakitlerden süzülür, ilçe ve yıl başına saklanır. Yıllık veri takvim yılını
  /// kapsadığından Ocak'tan önce gelecek Ramazan için boş dönebilir.
  static func imsakiye(districtId: String, window: RamadanWindow) async throws -> [PrayerDay] {
    let key = "@salah_imsakiye_v1_\(districtId)_\(window.hijriYear)"
    let keep = window.hijriYear != RamadanPlan.previewHijriYear
    if keep, let saved = LocalStore.decode([PrayerDay].self, key), saved.count >= 29 { return saved }
    guard !DebugLaunch.isIsolated, let year = await fetch(districtId: districtId, range: "yearly") else { throw URLError(.cannotLoadFromNetwork) }
    let days = RamadanPlan.imsakiye(year, window: window, calendar: .current)
    if keep, days.count >= 29 { LocalStore.encode(days, for: key) }
    return days
  }

  /// Önbellekteki bugün ve sonraki günler (ağa çıkmaz; widget'lar için).
  static func cachedDays(districtId: String) -> [PrayerDay] {
    withFallback(fromToday(readCache(districtId)?.days ?? []), districtId: districtId)
  }

  static func today(districtId: String) async -> PrayerDay? {
    let days = await upcomingDays(districtId: districtId)
    let today = Calendar.current.startOfDay(for: now())
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
    let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: now()))!
    let days = byDay.filter { $0.key >= yesterday }.sorted { $0.key < $1.key }.map(\.value)
    LocalStore.encode(Cache(fetchedAt: now().timeIntervalSince1970 * 1000, days: days), for: cachePrefix + districtId)
    learnCoordinates(districtId, days: days)
  }

  private static func fromToday(_ days: [PrayerDay]) -> [PrayerDay] {
    let today = Calendar.current.startOfDay(for: now())
    return days.filter { ($0.localDay ?? .distantPast) >= today }
  }

  /// Yıllık veri gerekli mi: elde yaklaşık bir yıl yoksa haftada bir; 30 günden az kaldıysa günde bir.
  private static func yearlyDue(_ districtId: String, coverDays: Int) -> Bool {
    guard coverDays < yearTargetDays else { return false }
    let last = LocalStore.string(yearlyAtPrefix + districtId).flatMap(Double.init) ?? 0
    let wait: TimeInterval = coverDays < longCoverDays ? 24 * 3600 : longFreshInterval
    return now().timeIntervalSince1970 - last >= wait
  }

  private static func covers(_ days: [PrayerDay]) -> Bool {
    days.count >= minCoverDays && days.first?.localDay == Calendar.current.startOfDay(for: now())
  }
}

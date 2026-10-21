import Foundation

/// Namaz işaretleri ve seri. RN'deki modules/gamification/gamification.store.ts
/// ile aynı davranış ve aynı cache (`@salah_gamification_cache`, zustand persist biçimi):
/// - İşaretleme iyimser: anında görünür, ağ yoksa kuyruğa alınır.
/// - Bekleyen mutation varken sunucu yanıtı yazılmaz (işaret "boşa düşmesin").
@Observable
final class GamificationStore {
  static let shared = GamificationStore()

  struct Stats: Codable, Equatable, Sendable {
    var today_prayers: [String] = []
    var kaza_prayers: [String] = []
    var current_streak: Int?
    var highest_streak: Int?
    var today_prayers_count: Int?

    enum CodingKeys: String, CodingKey {
      case today_prayers, kaza_prayers, current_streak, highest_streak, today_prayers_count
    }

    init() {}

    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      today_prayers = (try? c.decodeIfPresent([String].self, forKey: .today_prayers)) ?? []
      kaza_prayers = (try? c.decodeIfPresent([String].self, forKey: .kaza_prayers)) ?? []
      current_streak = Self.lenientInt(c, .current_streak)
      highest_streak = Self.lenientInt(c, .highest_streak)
      today_prayers_count = Self.lenientInt(c, .today_prayers_count)
    }

    /// Backend sayaçları bazen metin döndürüyor ("3").
    private static func lenientInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
      (try? c.decodeIfPresent(JSONValue.self, forKey: key))?.flatMap(\.intValue)
    }
  }

  /// Persist edilen alanlar. `badges`, `allBadges`, `weeklyStats` henüz taşınmayan
  /// ekranlar için biçimi bozulmadan saklanır.
  private struct Persisted: Codable {
    var stats: Stats?
    var statsDate: String?
    var badges: JSONValue?
    var allBadges: JSONValue?
    var weeklyStats: JSONValue?
  }

  private struct Envelope: Codable {
    var state: Persisted
    var version: Int = 0
  }

  struct TrackResult: Sendable {
    var offline = false
    var currentStreak = 0
    var todayCount = 0
    var streakIncremented = false
  }

  private static let cacheKey = "@salah_gamification_cache"
  private static let freshInterval: TimeInterval = 3

  private(set) var stats: Stats?
  /// `/gamification/stats/weekly` yanıtı (`daily: [{ date, prayer_count }]`).
  private(set) var weeklyStats: JSONValue?
  private(set) var isLoading = false
  /// Rozetler değişince görünümleri yenilemek için.
  private(set) var badgesVersion = 0
  @ObservationIgnored private var persisted = Persisted()

  @ObservationIgnored private var pendingMutations = 0
  @ObservationIgnored private var mutationSeq = 0
  @ObservationIgnored private var statsTask: Task<Void, Never>?
  @ObservationIgnored private var statsFetchedAt = Date.distantPast
  @ObservationIgnored private var weeklyTask: Task<Void, Never>?
  @ObservationIgnored private var weeklyFetchedAt = Date.distantPast

  private init() {
    if let env = LocalStore.decode(Envelope.self, Self.cacheKey) {
      persisted = env.state
      stats = env.state.stats
      weeklyStats = env.state.weeklyStats
    }
    ensureFreshToday()
  }

  /// Kazanılan rozetler (`[{ badge_id, details? }]`) ve tüm rozet tanımları (`{ id: { name, icon } }`).
  var badges: JSONValue? {
    _ = badgesVersion
    return persisted.badges
  }
  var allBadges: JSONValue? {
    _ = badgesVersion
    return persisted.allBadges
  }

  /// Persist edilen stats bir önceki güne aitse bugünün işaretlerini temizler.
  func ensureFreshToday() {
    let today = islamicDateString()
    guard var s = stats, persisted.statsDate != today else { return }
    s.today_prayers = []
    s.kaza_prayers = []
    if s.today_prayers_count != nil { s.today_prayers_count = 0 }
    setStats(s, date: today)
  }

  func fetchStats(force: Bool = false) async {
    if let statsTask { return await statsTask.value }
    guard force || Date().timeIntervalSince(statsFetchedAt) >= Self.freshInterval else { return }
    let seq = mutationSeq
    let task = Task {
      struct Response: Decodable {
        struct Payload: Decodable {
          var stats: Stats
          var badges: JSONValue?
          var allBadges: JSONValue?
        }
        var success: Bool
        var data: Payload?
      }
      if stats == nil { isLoading = true }
      defer { isLoading = false }
      guard let res = try? await APIClient.shared.get("/gamification/stats", as: Response.self),
        // Bu sırada işaretleme yapıldıysa yanıt eskidir; mutation kendi yenilemesini yapar.
        seq == mutationSeq, pendingMutations == 0,
        res.success, let payload = res.data
      else { return }
      statsFetchedAt = Date()
      persisted.badges = payload.badges
      persisted.allBadges = payload.allBadges
      badgesVersion += 1
      setStats(payload.stats, date: islamicDateString())
    }
    statsTask = task
    await task.value
    statsTask = nil
  }

  func fetchWeeklyStats(force: Bool = false) async {
    if let weeklyTask { return await weeklyTask.value }
    guard force || Date().timeIntervalSince(weeklyFetchedAt) >= Self.freshInterval else { return }
    let seq = mutationSeq
    let task = Task {
      struct Response: Decodable {
        var success: Bool
        var data: JSONValue?
      }
      guard let res = try? await APIClient.shared.get("/gamification/stats/weekly", as: Response.self),
        seq == mutationSeq, pendingMutations == 0, res.success, let data = res.data
      else { return }
      weeklyFetchedAt = Date()
      weeklyStats = data
      persisted.weeklyStats = data
      LocalStore.encode(Envelope(state: persisted), for: Self.cacheKey)
    }
    weeklyTask = task
    await task.value
    weeklyTask = nil
  }

  /// - Parameter prayerId: fajr | dhuhr | asr | maghrib | isha
  func trackPrayer(_ prayerId: String, isKaza: Bool) async throws -> TrackResult? {
    guard !OzelGunStore.shared.isActive else { return nil }
    var s = stats ?? Stats()
    guard !s.today_prayers.contains(prayerId) else { return nil }
    s.today_prayers.append(prayerId)
    if isKaza { s.kaza_prayers.append(prayerId) }
    setStats(s, date: islamicDateString())

    beginMutation()
    defer { endMutation() }
    do {
      struct Response: Decodable {
        struct Payload: Decodable {
          var stats: Stats?
          var streakIncremented: Bool?
        }
        var success: Bool
        var data: Payload?
      }
      let res: Response = try await APIClient.shared.post(
        "/prayer/track", body: ["prayer_time": .string(prayerId), "is_kaza": .bool(isKaza)])
      guard res.success, let payload = res.data else { return nil }
      // Yanıttaki stats today_prayers içermez; yalnız seri alanları birleştirilir.
      if var current = stats {
        current.current_streak = payload.stats?.current_streak ?? current.current_streak
        current.highest_streak = payload.stats?.highest_streak ?? current.highest_streak
        setStats(current, date: persisted.statsDate)
      }
      return TrackResult(
        currentStreak: payload.stats?.current_streak ?? 0,
        todayCount: payload.stats?.today_prayers_count ?? 0,
        streakIncremented: payload.streakIncremented ?? false
      )
    } catch {
      if error.isNetworkError {
        // Çevrimdışı: iyimser işareti KORU, isteği bugünün tarihiyle kuyruğa al.
        OfflineQueue.shared.enqueue(
          method: "post", url: "/prayer/track",
          body: ["prayer_time": .string(prayerId), "is_kaza": .bool(isKaza), "date": .string(islamicDateString())])
        return TrackResult(offline: true)
      }
      // 400 = zaten kayıtlı: işaret doğru, geri alma.
      if (error as? APIError)?.status != 400 { removeMark(prayerId) }
      throw error
    }
  }

  func untrackPrayer(_ prayerId: String) async throws {
    let wasKaza = stats?.kaza_prayers.contains(prayerId) ?? false
    removeMark(prayerId)

    beginMutation()
    defer { endMutation() }
    do {
      try await APIClient.shared.send("DELETE", "/prayer/track", body: ["prayer_time": .string(prayerId)])
    } catch {
      if error.isNetworkError {
        OfflineQueue.shared.enqueue(
          method: "delete", url: "/prayer/track",
          body: ["prayer_time": .string(prayerId), "date": .string(islamicDateString())])
        return
      }
      if var s = stats {
        s.today_prayers.append(prayerId)
        if wasKaza { s.kaza_prayers.append(prayerId) }
        setStats(s, date: persisted.statsDate)
      }
      throw error
    }
  }

  // MARK: - Internals

  private func removeMark(_ prayerId: String) {
    guard var s = stats else { return }
    s.today_prayers.removeAll { $0 == prayerId }
    s.kaza_prayers.removeAll { $0 == prayerId }
    setStats(s, date: persisted.statsDate)
  }

  private func beginMutation() {
    pendingMutations += 1
    mutationSeq += 1
  }

  /// Son mutation bitince sunucunun gerçeğiyle tek bir yenileme.
  private func endMutation() {
    pendingMutations -= 1
    guard pendingMutations == 0 else { return }
    Task {
      await statsTask?.value
      await weeklyTask?.value
      guard pendingMutations == 0 else { return }
      async let stats: Void = fetchStats(force: true)
      async let weekly: Void = fetchWeeklyStats(force: true)
      _ = await (stats, weekly)
    }
  }

  /// Çıkışta: önceki kullanıcının işaretleri/serisi bu cihazda kalmasın, vakit kartı
  /// da onlara göre "kılındı" saymasın.
  func reset() {
    // Yolda olan bir yanıt eski kullanıcının verisini geri yazmasın.
    mutationSeq += 1
    statsTask?.cancel()
    weeklyTask?.cancel()
    persisted = Persisted()
    stats = nil
    weeklyStats = nil
    badgesVersion += 1
    statsFetchedAt = .distantPast
    weeklyFetchedAt = .distantPast
    LocalStore.encode(Envelope(state: persisted), for: Self.cacheKey)
    WidgetBridge.updateTracker(completed: [], kaza: [], date: islamicDateString())
    WidgetSync.updatePrayer(nil)
  }

  private func setStats(_ s: Stats, date: String?) {
    stats = s
    persisted.stats = s
    persisted.statsDate = date
    LocalStore.encode(Envelope(state: persisted), for: Self.cacheKey)
    // Kayıtların ait olduğu namaz günü (backend ile aynı, 04:00 sınırlı).
    WidgetBridge.updateTracker(completed: s.today_prayers, kaza: s.kaza_prayers, date: date ?? islamicDateString())
    // Kılınan namaz vakit widget'ının ve Live Activity'nin penceresini değiştirir.
    WidgetSync.updatePrayer(nil)
  }

  #if DEBUG
  /// Mağaza görseli fikstürü: bugünkü namazlar, seri ve haftalık görünüm (yalnız bellek).
  func preview(stats: Stats, weekly: JSONValue?) {
    self.stats = stats
    weeklyStats = weekly
  }
  #endif
}

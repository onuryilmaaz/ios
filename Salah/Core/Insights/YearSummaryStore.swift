import Foundation
import Observation

/// Yıl özeti (`GET /gamification/year?year=`). Son sonuç yıl başına saklanır; ağ yoksa o gösterilir.
struct YearSummary: Codable, Equatable {
  struct Count: Codable, Equatable { var count: Int; var rakaat: Double }
  struct Sadaka: Codable, Equatable { var count: Int; var amount: Double }
  struct Month: Codable, Equatable { var month: Int; var prayers: Int }

  var year: Int
  var days: Int
  var prayers: Int
  var possiblePrayers: Int
  var perfectDays: Int
  var longestStreak: Int
  var byPrayerTime: [String: Int]
  var bestMonth: Month?
  var kazaMarked: Int
  var kazaPaid: Int
  var quranPages: Int
  var hatims: Int
  var nafile: Count
  var teheccud: Count
  var fastingDays: Int
  var sadaka: Sadaka
  var duaMinutes: Int
  var memorizedAyets: Int

  /// Kılınan vakitlerin olası vakitlere oranı (0...100).
  var percent: Int { possiblePrayers > 0 ? min(100, Int((Double(prayers) / Double(possiblePrayers) * 100).rounded())) : 0 }
  var isEmpty: Bool { prayers == 0 && quranPages == 0 && nafile.count == 0 && fastingDays == 0 && sadaka.count == 0 && kazaPaid == 0 }

  /// Vakitler sabah → yatsı sırasıyla.
  static let prayerOrder = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
}

@MainActor
@Observable
final class YearSummaryStore {
  static let shared = YearSummaryStore()
  private(set) var summaries: [Int: YearSummary] = [:]
  private(set) var loading = false
  private(set) var failed = false

  static var available: Bool {
    AppControlStore.shared.supports("yearSummary") && AuthStore.shared.isAuthenticated && !years().isEmpty
  }

  /// Açıklanma saati: 1 Ocak, yerel saatle 10.00.
  static let revealHour = 10

  /// Yıl özeti yılbaşından sonra açıklanır: 1 Ocak 10.00'dan Ocak sonuna kadar, biten yıl için. Diğer zamanlarda nil.
  static func revealedYear(now: Date = Date(), calendar: Calendar = .current) -> Int? {
    let parts = calendar.dateComponents([.year, .month, .day, .hour], from: now)
    guard parts.month == 1, let year = parts.year, let day = parts.day, let hour = parts.hour else { return nil }
    guard day > 1 || hour >= revealHour else { return nil }
    return year - 1
  }

  private func storyKey(_ year: Int) -> String { "@salah_year_story_shown_v1_\(AuthStore.shared.user?.id ?? "-")_\(year)" }

  /// Açıklanan yılın hikâyesi bu hesaba henüz kendiliğinden gösterilmediyse o yıl (özet yüklenir; boşsa gösterilmez).
  /// Debug: `-SalahDebugYearStory YES` tarih ve "gösterildi" bilgisinden bağımsız açar.
  func pendingStory(now: Date = Date()) async -> Int? {
    guard AppControlStore.shared.supports("yearSummary"), AuthStore.shared.isAuthenticated else { return nil }
    var forced = false
    #if DEBUG
    forced = UserDefaults.standard.bool(forKey: "SalahDebugYearStory")
    #endif
    guard let year = Self.revealedYear(now: now) ?? (forced ? Self.years(now: now).first ?? Calendar.current.component(.year, from: now) - 1 : nil)
    else { return nil }
    if !forced, LocalStore.string(storyKey(year)) == "true" { return nil }
    await load(year)
    guard let summary = cached(year) else { return nil }
    if summary.isEmpty {
      markStoryShown(year)
      return nil
    }
    return year
  }

  func markStoryShown(_ year: Int) { LocalStore.set("true", for: storyKey(year)) }

  /// Gösterilen yıl (açıklanma dışında boş). Debug izole önizlemede her zaman geçen yıl.
  static func years(now: Date = Date()) -> [Int] {
    #if DEBUG
    if DebugLaunch.isIsolated { return [Calendar.current.component(.year, from: now) - 1] }
    #endif
    return revealedYear(now: now).map { [$0] } ?? []
  }

  @ObservationIgnored private var owner: String?

  /// Önbellek hesaba bağlı: başka hesapla girilince eski özet görünmez.
  private func key(_ year: Int) -> String { "@salah_year_summary_v1_\(AuthStore.shared.user?.id ?? "-")_\(year)" }

  private func checkOwner() {
    let current = AuthStore.shared.user?.id
    if owner != current { owner = current; summaries = [:] }
  }

  func cached(_ year: Int) -> YearSummary? {
    checkOwner()
    return summaries[year] ?? LocalStore.decode(YearSummary.self, key(year))
  }

  func load(_ year: Int) async {
    checkOwner()
    if summaries[year] == nil, let saved = LocalStore.decode(YearSummary.self, key(year)) { summaries[year] = saved }
    #if DEBUG
    if DebugLaunch.isIsolated {
      summaries[year] = .init(
        year: year, days: 318, prayers: 1342, possiblePrayers: 1590, perfectDays: 201, longestStreak: 47,
        byPrayerTime: ["fajr": 236, "dhuhr": 281, "asr": 274, "maghrib": 290, "isha": 261], bestMonth: .init(month: 3, prayers: 148),
        kazaMarked: 12, kazaPaid: 86, quranPages: 1288, hatims: 2, nafile: .init(count: 164, rakaat: 412),
        teheccud: .init(count: 58, rakaat: 166), fastingDays: 41, sadaka: .init(count: 23, amount: 0), duaMinutes: 310, memorizedAyets: 74)
      return
    }
    #endif
    guard !DebugLaunch.isIsolated else { return }
    struct Response: Decodable { var success: Bool; var data: YearSummary? }
    loading = true
    failed = false
    defer { loading = false }
    do {
      let res = try await APIClient.shared.get("/gamification/year?year=\(year)", as: Response.self)
      guard let data = res.data else { return }
      summaries[year] = data
      LocalStore.encode(data, for: key(year))
    } catch {
      if summaries[year] == nil { failed = true }
    }
  }
}

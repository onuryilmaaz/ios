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

  static var available: Bool { AppControlStore.shared.supports("yearSummary") && AuthStore.shared.isAuthenticated }

  /// Bu yıl ve geçen yıl (kayıt varsa seçilebilir).
  static func years(now: Date = Date()) -> [Int] {
    let year = Calendar.current.component(.year, from: now)
    return [year, year - 1]
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

import Foundation

/// İbadet sekmesindeki istatistikler (ısı haritası, haftalık/aylık özet, hatim).
/// Son veri cihazda saklanır (`@salah_insights_cache`). Sunucuda uç yoksa (404)
/// bölüm gizlenir. RN: modules/insights/insights.store.ts
///
/// Premium şu an kapalı (`PREMIUM_ENABLED=false`); tüm uçlar herkese açık.
@Observable
final class InsightsStore {
  static let shared = InsightsStore()

  struct HistoryDay: Codable, Equatable, Sendable {
    var date: String
    var count: Int
    var kaza: Int?
  }

  struct History: Codable, Equatable, Sendable {
    var from: String
    var to: String
    var days: [HistoryDay]
    var ozelGun: [String]
  }

  struct Recap: Codable, Equatable, Sendable {
    var period: String
    var from: String
    var to: String
    var days: Int
    var prayers: Int
    var possiblePrayers: Int
    var kaza: Int
    var perfectDays: Int
    var byPrayerTime: [String: Int]
    var quranPages: Int
    var activities: [String: Int]
    var currentStreak: Int?
    var highestStreak: Int?
  }

  struct QuranProgress: Codable, Equatable, Sendable {
    var totalPages: Int
    var completedHatims: Int
    var currentPages: Int
    var pagesPerHatim: Int
  }

  enum Period: String, Sendable { case week, month }

  private struct Persisted: Codable {
    var history: History?
    var recaps: [String: Recap]?
    var quran: QuranProgress?
  }

  private struct Envelope: Codable {
    var state: Persisted
    var version: Int = 0
  }

  private static let cacheKey = "@salah_insights_cache"

  private(set) var history: History?
  private(set) var recaps: [String: Recap] = [:]
  private(set) var quran: QuranProgress?
  private(set) var unavailable = false

  private init() {
    if let env = LocalStore.decode(Envelope.self, Self.cacheKey) {
      history = env.state.history
      recaps = env.state.recaps ?? [:]
      quran = env.state.quran
    }
  }

  func recap(_ period: Period) -> Recap? { recaps[period.rawValue] }

  func fetchAll() async {
    // Dört uç paralel; Task'lar ana aktörde kalır (sonuçlar doğrudan store'a yazılır).
    let tasks = [
      Task { await load("/gamification/recap?period=week", Recap.self) { self.recaps["week"] = $0 } },
      Task { await load("/gamification/recap?period=month", Recap.self) { self.recaps["month"] = $0 } },
      Task { await load("/gamification/history?days=371", History.self) { self.history = $0 } },
      Task { await load("/gamification/quran-progress", QuranProgress.self) { self.quran = $0 } },
    ]
    for task in tasks { await task.value }
    LocalStore.encode(Envelope(state: Persisted(history: history, recaps: recaps, quran: quran)), for: Self.cacheKey)
  }

  private struct Response<D: Decodable>: Decodable {
    var success: Bool?
    var data: D?
  }

  private func load<T: Decodable>(_ path: String, _ type: T.Type, apply: (T) -> Void) async {
    do {
      let res = try await APIClient.shared.get(path, as: Response<T>.self)
      if res.success == true, let data = res.data {
        apply(data)
        unavailable = false
      }
    } catch {
      if (error as? APIError)?.status == 404 { unavailable = true }
    }
  }

  #if DEBUG
  /// Mağaza görseli fikstürü: 12 aylık geçmiş, haftalık/aylık özet ve hatim ilerlemesi (yalnız bellek).
  func preview(history: History, recaps: [String: Recap], quran: QuranProgress) {
    self.history = history
    self.recaps = recaps
    self.quran = quran
    unavailable = false
  }
  #endif
}

/// Isı haritası hesapları. RN: modules/insights/heatmap.ts
enum Heatmap {
  struct Cell: Equatable {
    let date: String
    let count: Int
    let ozelGun: Bool
    /// Bugünden sonraki (son sütunun boş kalan) günler.
    let future: Bool
  }

  struct Column: Equatable {
    /// Pazartesi … Pazar
    let cells: [Cell]
    /// Bu sütunda yeni bir ay başlıyorsa ayın indeksi (0-11).
    let monthStart: Int?
  }

  /// `weeks` sütun; son sütun bugünün haftası.
  static func build(_ history: InsightsStore.History, weeks: Int = 53) -> [Column] {
    let cal = Calendar.current
    let counts = Dictionary(history.days.map { ($0.date, $0.count) }, uniquingKeysWith: { a, _ in a })
    let ozel = Set(history.ozelGun)
    guard let today = parse(history.to) else { return [] }
    let mondayOffset = (cal.component(.weekday, from: today) + 5) % 7
    let start = cal.date(byAdding: .day, value: -mondayOffset - (weeks - 1) * 7, to: today)!

    var columns: [Column] = []
    var prevMonth = -1
    for w in 0..<weeks {
      let cells = (0..<7).map { r -> Cell in
        let d = cal.date(byAdding: .day, value: w * 7 + r, to: start)!
        let key = localDateString(d)
        return Cell(date: key, count: counts[key] ?? 0, ozelGun: ozel.contains(key), future: d > today)
      }
      let month = cal.component(.month, from: parse(cells[0].date)!) - 1
      columns.append(Column(cells: cells, monthStart: month != prevMonth && w > 0 ? month : nil))
      prevMonth = month
    }
    return columns
  }

  /// 0 boş, 1: 1-2 vakit, 2: 3-4 vakit, 3: beş vakit.
  static func level(_ count: Int) -> Int {
    count >= 5 ? 3 : count >= 3 ? 2 : count >= 1 ? 1 : 0
  }

  static func summarize(_ history: InsightsStore.History) -> (prayers: Int, perfectDays: Int) {
    (history.days.reduce(0) { $0 + $1.count }, history.days.filter { $0.count >= 5 }.count)
  }

  /// "YYYY-MM-DD" → yerel gün.
  static func parse(_ ymd: String) -> Date? {
    let p = ymd.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return nil }
    return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
  }
}

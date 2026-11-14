import Foundation
import Observation

/// Ezber: ayet başına aralıklı tekrar (Leitner kutuları). Hatırladıkça aralık uzar (1, 2, 4, 7, 15, 30 gün), zorlanınca
/// yarıya iner, unutunca baştan başlar. Android `core/hifz/HifzStore.kt` ile aynı kurallar.
enum HifzPlan {
  static let intervals = [1, 2, 4, 7, 15, 30]
  /// Bu kutudan itibaren ayet "sağlam" sayılır.
  static let strongBox = 4

  struct Card: Codable, Equatable, Sendable, Identifiable {
    var surah: Int
    var verse: Int
    /// Ses için genel ayet kimliği (1...6236).
    var globalId: Int
    var box = 0
    /// Tekrar günü, yyyy-MM-dd.
    var due: String
    var reviews = 0
    var lapses = 0
    var id: String { "\(surah):\(verse)" }
  }

  enum Rating: Sendable { case remembered, hard, forgot }

  static func day(_ d: Date, plus days: Int = 0) -> String {
    localDateString(Calendar.current.date(byAdding: .day, value: days, to: d) ?? d)
  }

  static func rate(_ card: Card, _ rating: Rating, today: Date) -> Card {
    var c = card
    c.reviews += 1
    switch rating {
    case .remembered:
      c.box = min(c.box + 1, intervals.count - 1)
      c.due = day(today, plus: intervals[c.box])
    case .hard:
      c.due = day(today, plus: max(1, intervals[c.box] / 2))
    case .forgot:
      c.box = 0
      c.lapses += 1
      c.due = day(today, plus: 1)
    }
    return c
  }

  /// Bugün (ve gecikmiş) tekrar edilecekler, Mushaf sırasıyla.
  static func due(_ cards: [Card], today: Date) -> [Card] {
    let t = day(today)
    return cards.filter { $0.due <= t }.sorted { ($0.surah, $0.verse) < ($1.surah, $1.verse) }
  }

  /// Ayet aralığından yeni kartlar (ayet no, genel kimlik); zaten listede olanlar atlanır.
  static func add(_ cards: [Card], surah: Int, verses: [(Int, Int)], today: Date) -> [Card] {
    let existing = Set(cards.map(\.id))
    let added = verses.filter { !existing.contains("\(surah):\($0.0)") }.map { Card(surah: surah, verse: $0.0, globalId: $0.1, due: day(today)) }
    return (cards + added).sorted { ($0.surah, $0.verse) < ($1.surah, $1.verse) }
  }
}

/// Ezber listesi: cihazda (`@salah_hifz_v1`, Android ile aynı biçim).
@MainActor
@Observable
final class HifzStore {
  static let shared = HifzStore()
  private static let key = "@salah_hifz_v1"

  private(set) var cards: [HifzPlan.Card]

  private init() {
    cards = LocalStore.decode([HifzPlan.Card].self, Self.key) ?? []
  }

  func due(_ today: Date = Date()) -> [HifzPlan.Card] { HifzPlan.due(cards, today: today) }
  var strongCount: Int { cards.filter { $0.box >= HifzPlan.strongBox }.count }

  func add(surah: Int, verses: [(Int, Int)]) {
    save(HifzPlan.add(cards, surah: surah, verses: verses, today: Date()))
  }

  func removeSurah(_ surah: Int) { save(cards.filter { $0.surah != surah }) }

  func rate(_ card: HifzPlan.Card, _ rating: HifzPlan.Rating) {
    UsageStore.shared.record("hifz.review")
    save(cards.map { $0.id == card.id ? HifzPlan.rate($0, rating, today: Date()) : $0 })
  }

  private func save(_ list: [HifzPlan.Card]) {
    cards = list
    LocalStore.encode(list, for: Self.key)
  }
}

import Foundation
import Testing
@testable import Salah

@MainActor
struct KazaPlanTests {
  let cal = Calendar.current
  func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

  @Test func totalRespectsWitr() {
    let counts = ["fajr": 10, "isha": 5, "witr": 7]
    #expect(KazaPlan.total(counts, witr: false) == 15)
    #expect(KazaPlan.total(counts, witr: true) == 22)
  }

  @Test func finishUsesLargestCounter() {
    // En büyük 10, günde 3 → 4 gün: bugün dahil 4. gün.
    let finish = KazaPlan.finishDate(["fajr": 10, "dhuhr": 2], witr: false, perDay: 3, from: day(2026, 11, 12))
    #expect(finish.map { cal.component(.day, from: $0) } == 15)
    #expect(KazaPlan.finishDate([:], witr: false, perDay: 1, from: Date()) == nil)
  }

  @Test func owedDaysInclusiveAndDeducted() {
    #expect(KazaPlan.owedDays(from: day(2026, 1, 1), to: day(2026, 1, 1), monthlyExemptDays: 0) == 1)
    #expect(KazaPlan.owedDays(from: day(2025, 1, 1), to: day(2025, 12, 31), monthlyExemptDays: 0) == 365)
    // 365 gün, ayda 7 gün → ~84 gün düşülür.
    #expect(KazaPlan.owedDays(from: day(2025, 1, 1), to: day(2025, 12, 31), monthlyExemptDays: 7) == 281)
    #expect(KazaPlan.owedDays(from: day(2026, 2, 1), to: day(2026, 1, 1), monthlyExemptDays: 0) == 0)
  }
}

@MainActor
struct HomeRemoteLayoutTests {
  typealias S = HomeLayoutStore.Section

  @Test func remoteOrderAppliesAndUnknownKeysDrop() {
    let r = HomeLayoutStore.remoteDefaults(order: ["streak", "ramadanHero", "prayerTracker"], hidden: ["streak"])
    #expect(r.first?.key == .streak)
    #expect(r.first?.visible == false)
    #expect(Set(r.map(\.key)) == Set(HomeLayoutStore.Key.allCases))
    // Listede olmayan kaza yerleşik varsayılanla (gizli) eklenir.
    #expect(r.first { $0.key == .kaza }?.visible == false)
  }

  @Test func userLayoutWinsAndNewCardTakesRemoteDefault() {
    let remote = HomeLayoutStore.remoteDefaults(order: ["kaza", "prayerTracker", "alarms", "streak", "quickActions", "dailyInspiration", "dayRing"], hidden: [])
    // Eski kayıt (kaza yok): kullanıcının sırası korunur, kaza panelin yerinde ve görünür eklenir.
    let stored = [S(key: .dayRing, visible: true), S(key: .prayerTracker, visible: false)]
    let result = HomeLayoutStore.reconcile(stored, defaults: remote)
    #expect(result.first?.key == .kaza)
    #expect(result.first?.visible == true)
    #expect(result.firstIndex { $0.key == .dayRing }! < result.firstIndex { $0.key == .prayerTracker }!)
    #expect(result.first { $0.key == .prayerTracker }?.visible == false)
  }
}

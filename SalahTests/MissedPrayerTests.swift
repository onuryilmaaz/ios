import Foundation
import Testing
@testable import Salah

@MainActor
struct MissedPrayerTests {
  typealias F = NotificationFixtures

  @Test func remindsBeforePrayerEnds() {
    let plan = NotificationPlan.build(days: F.days, preferences: F.enabled, now: F.date(19, 6, 0), calendar: F.calendar,
      missed: MissedReminder(prayers: ["imsak", "yatsi"], done: []))
      .filter { $0.kind == .missed }
    // 19'u sabahı: güneş 06:49 - 30 dk = 06:19; yatsı 20:10 + 90 dk = 21:40. 20'si için ikisi daha.
    #expect(plan.count == 4)
    #expect(plan.first?.id == "missed.2026-10-19.fajr")
    #expect(plan.first?.date == F.date(19, 6, 19))
    #expect(plan.contains { $0.id == "missed.2026-10-19.isha" && $0.date == F.date(19, 21, 40) })
  }

  @Test func skipsMarkedAndPastAndAtMostTwoPerDay() {
    let plan = NotificationPlan.build(days: F.days, preferences: F.enabled, now: F.date(19, 7, 0), calendar: F.calendar,
      missed: MissedReminder(prayers: ["ogle", "ikindi", "yatsi"], done: ["2026-10-19.dhuhr"]))
      .filter { $0.kind == .missed }
    #expect(!plan.contains { $0.id == "missed.2026-10-19.dhuhr" })
    #expect(plan.contains { $0.id == "missed.2026-10-19.asr" && $0.date == F.date(19, 18, 21) })
    #expect(!plan.contains { $0.id.hasSuffix(".isha") })
    #expect(plan.filter { $0.id.contains("2026-10-20") }.count == 2)
  }

  @Test func turnedOff() {
    var p = F.enabled
    p.missed = false
    #expect(NotificationPlan.build(days: F.days, preferences: p, now: F.date(19, 6, 0), calendar: F.calendar,
      missed: MissedReminder(prayers: ["imsak"], done: [])).allSatisfy { $0.kind != .missed })
  }

  @Test func choosesLeastOffered() {
    #expect(MissedPrayers.choose(["fajr": 20, "dhuhr": 28, "asr": 12, "maghrib": 30, "isha": 25]) == ["ikindi", "imsak"])
    #expect(MissedPrayers.choose(nil) == ["imsak", "yatsi"])
  }
}

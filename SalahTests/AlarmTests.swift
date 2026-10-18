import Foundation
import Testing
@testable import Salah

/// RN'deki src/modules/alarm/__tests__/alarm.plan.test.ts ile aynı girdiler ve beklentiler.
@MainActor
struct AlarmPlanTests {
  static func times(_ imsak: String) -> [String: String] {
    ["imsak": imsak, "gunes": "07:10", "ogle": "13:05", "ikindi": "16:10", "aksam": "18:45", "yatsi": "20:05"]
  }

  /// 3, 4, 5 Ekim 2026 (API tarihleri UTC gece yarısı).
  let days = [
    AlarmPlan.Day(date: "2026-10-03T00:00:00.000Z", times: times("05:41"), hijriMonth: 4),
    AlarmPlan.Day(date: "2026-10-04T00:00:00.000Z", times: times("05:42"), hijriMonth: 4),
    AlarmPlan.Day(date: "2026-10-05T00:00:00.000Z", times: times("05:43"), hijriMonth: 9),
  ]

  func at(_ d: Int, _ h: Int, _ m: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: d, hour: h, minute: m))!
  }

  func fmt(_ date: Date) -> String {
    let c = Calendar.current.dateComponents([.day, .hour, .minute], from: date)
    return String(format: "%02d %02d:%02d", c.day!, c.hour!, c.minute!)
  }

  func settings(_ change: (inout AlarmSettings) -> Void) -> AlarmSettings {
    var s = AlarmSettings.defaults
    change(&s)
    return s
  }

  @Test func prayerAlarmShiftsWithEachDay() {
    let s = settings { $0.prayers["imsak"] = .init(enabled: true, offset: 15) }
    #expect(AlarmPlan.build(days: days, settings: s, now: at(3, 1, 0)).map { fmt($0.fireAt) } == ["03 05:56", "04 05:57", "05 05:58"])
  }

  @Test func pastAlarmsAreSkipped() {
    let s = settings { $0.prayers["ogle"] = .init(enabled: true, offset: -10) }
    #expect(AlarmPlan.build(days: days, settings: s, now: at(3, 14, 0)).map { fmt($0.fireAt) } == ["04 12:55", "05 12:55"])
  }

  @Test func tahajjudIsLastThirdOfNight() {
    let s = settings { $0.tahajjud = .init(enabled: true, offset: 0) }
    // 18:45 → 05:42 = 657 dk; 2/3 = 438 dk → 02:03
    #expect(AlarmPlan.build(days: days, settings: s, now: at(3, 12, 0)).map { fmt($0.fireAt) } == ["04 02:03", "05 02:04"])
  }

  @Test func afterMidnightCurrentNightTahajjud() {
    let s = settings { $0.tahajjud = .init(enabled: true, offset: 0) }
    #expect(fmt(AlarmPlan.build(days: days, settings: s, now: at(3, 1, 0))[0].fireAt) == "03 02:02")
  }

  @Test func sahurOnlyInRamadan() {
    let s = settings { $0.sahur = .init(enabled: true, minutesBefore: 45, onlyRamadan: true) }
    #expect(AlarmPlan.build(days: days, settings: s, now: at(3, 1, 0)).map { fmt($0.fireAt) } == ["05 04:58"])
  }

  @Test func sahurEveryDay() {
    let s = settings { $0.sahur = .init(enabled: true, minutesBefore: 30, onlyRamadan: false) }
    #expect(AlarmPlan.build(days: days, settings: s, now: at(3, 1, 0)).count == 3)
  }

  @Test func customAlarmOnSelectedWeekdays() {
    // 3 Ekim 2026 Cumartesi (6); Pazartesi (1) ve Cumartesi seçili.
    let s = settings { $0.custom = [.init(id: "a", hour: 7, minute: 30, days: [1, 6], onceAt: nil, label: "", enabled: true)] }
    #expect(AlarmPlan.build(days: [], settings: s, now: at(3, 8, 0), horizonDays: 10).map { fmt($0.fireAt) } == ["05 07:30", "10 07:30", "12 07:30"])
  }

  @Test func oneShotCustomNotRescheduledAfterFiring() {
    let once = at(3, 7, 0).timeIntervalSince1970 * 1000
    let s = settings { $0.custom = [.init(id: "a", hour: 7, minute: 0, days: [], onceAt: once, label: "", enabled: true)] }
    #expect(AlarmPlan.build(days: [], settings: s, now: at(3, 6, 0)).count == 1)
    #expect(AlarmPlan.build(days: [], settings: s, now: at(3, 7, 1)).isEmpty)
  }

  @Test func daysBeyondHorizonSkipped() {
    let s = settings { $0.prayers["yatsi"] = .init(enabled: true, offset: 0) }
    #expect(AlarmPlan.build(days: days, settings: s, now: at(3, 1, 0), horizonDays: 2).count == 2)
  }

  @Test func lastThirdRoundsToMinute() {
    #expect(fmt(AlarmPlan.lastThirdStart(maghrib: at(3, 18, 45), nextFajr: at(4, 5, 42))) == "04 02:03")
  }

  @Test func nextOccurrenceMovesToTomorrowWhenPast() {
    let now = at(3, 8, 0)
    #expect(fmt(AlarmPlan.nextOccurrence(hour: 7, minute: 0, now: now)) == "04 07:00")
    #expect(fmt(AlarmPlan.nextOccurrence(hour: 9, minute: 0, now: now)) == "03 09:00")
  }

  /// RN'nin kaydettiği eksik/eski JSON varsayılanlarla tamamlanır; geçersiz ses düzelir.
  @Test func decodesPartialRNSettings() throws {
    let raw = #"{"prayers":{"ogle":{"enabled":true,"offset":5}},"sound":"bogus","custom":[{"id":"x","hour":6,"minute":0,"days":[],"onceAt":1790000000000,"label":"Kalk","enabled":true}]}"#
    let s = try JSONDecoder().decode(AlarmSettings.self, from: Data(raw.utf8))
    #expect(s.prayers["ogle"] == .init(enabled: true, offset: 5))
    #expect(s.prayers["imsak"] == .init(enabled: false, offset: 15))
    #expect(s.sound == "adhan")
    #expect(s.sahur.minutesBefore == 45)
    #expect(s.custom.first?.label == "Kalk")
  }

  @Test func markPrayerKazaRule() {
    let t = PrayerTimes(imsak: "05:40", gunes: "07:05", ogle: "13:00", ikindi: "16:15", aksam: "18:45", yatsi: "20:05")
    #expect(!AlarmMarkPrayer.isExpired("dhuhr", times: t, now: at(3, 13, 30)))
    #expect(AlarmMarkPrayer.isExpired("dhuhr", times: t, now: at(3, 16, 30)))
    #expect(AlarmMarkPrayer.isExpired("fajr", times: t, now: at(3, 3, 0)))
    #expect(!AlarmMarkPrayer.isExpired("isha", times: t, now: at(3, 23, 0)))
  }
}

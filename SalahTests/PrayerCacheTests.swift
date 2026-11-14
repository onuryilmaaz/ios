import Foundation
import Testing
@testable import Salah

/// Yıllık önbellek: uygulama uzun süre açılmasa ya da çevrimdışı kalsa da vakitler elde olsun. Android PrayerTimesServiceTest.
@MainActor
@Suite(.serialized)
struct PrayerCacheTests {
  let district = "test-yearly"
  let cal = Calendar.current
  let start: Date
  let times = PrayerTimes(imsak: "05:00", gunes: "06:30", ogle: "12:30", ikindi: "15:30", aksam: "18:00", yatsi: "19:30")

  init() {
    start = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10))!
    LocalStore.remove("@salah_prayer_times_cache_test-yearly", "@salah_prayer_times_yearly_at_test-yearly")
  }

  func days(_ count: Int) -> [PrayerDay] {
    (0..<count).map { i in
      let d = cal.date(byAdding: .day, value: i, to: start)!
      let c = cal.dateComponents([.year, .month, .day], from: d)
      return PrayerDay(date: String(format: "%04d-%02d-%02dT00:00:00.000Z", c.year!, c.month!, c.day!), times: times)
    }
  }

  func run(at date: Date, yearly: Int = 300, failYearly: Bool = false, calls: inout [String]) async -> Int {
    var log: [String] = []
    PrayerTimesService.now = { date }
    PrayerTimesService.fetcher = { _, range in
      log.append(range)
      switch range {
      case "yearly": return failYearly ? nil : days(yearly)
      case "monthly": return days(30)
      default: return days(7)
      }
    }
    let result = await PrayerTimesService.upcomingDays(districtId: district)
    calls += log
    return result.count
  }

  func reset() {
    PrayerTimesService.now = { Date() }
    LocalStore.remove("@salah_prayer_times_cache_test-yearly", "@salah_prayer_times_yearly_at_test-yearly")
  }

  @Test func firstLoadFetchesYearly() async {
    defer { reset() }
    var calls: [String] = []
    #expect(await run(at: start, calls: &calls) == 300)
    #expect(calls == ["yearly"])
  }

  @Test func longCacheSkipsNetworkForAWeek() async {
    defer { reset() }
    var calls: [String] = []
    _ = await run(at: start, calls: &calls)
    #expect(await run(at: start.addingTimeInterval(6 * 86400), calls: &calls) == 294)
    #expect(calls == ["yearly"])
  }

  @Test func yearlyFailureFallsBackToMonthly() async {
    defer { reset() }
    var calls: [String] = []
    #expect(await run(at: start, failYearly: true, calls: &calls) == 30)
    #expect(calls == ["yearly", "monthly"])
  }

  @Test func shortYearRetriedWeekly() async {
    defer { reset() }
    var calls: [String] = []
    _ = await run(at: start, yearly: 40, calls: &calls)
    _ = await run(at: start.addingTimeInterval(8 * 86400), yearly: 40, calls: &calls)
    #expect(calls == ["yearly", "yearly"])
    _ = await run(at: start.addingTimeInterval(9 * 86400), yearly: 40, calls: &calls)
    #expect(calls == ["yearly", "yearly"])
  }
}

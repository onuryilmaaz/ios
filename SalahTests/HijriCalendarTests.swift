import Foundation
import Testing
@testable import Salah

@MainActor
enum HijriCalendarFixture {
  static var clock: Calendar { NotificationFixtures.calendar }
  static func date(_ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    clock.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
  }
  /// Açık yıllık API'den alınan gerçek 365 gün; uygulama backend'i kullanılmaz.
  static func cache() throws -> ReligiousCalendar.Cache {
    let url = try #require(Bundle.main.url(forResource: "HijriCalendarPreview", withExtension: "json"))
    return try JSONDecoder().decode(ReligiousCalendar.Cache.self, from: Data(contentsOf: url))
  }
  static func calendar() throws -> ReligiousCalendar { .init(cache: try cache(), calendar: clock) }
}

@MainActor
struct HijriCalendarGridTests {
  typealias F = HijriCalendarFixture

  @Test func normalizesMonthAcrossYearInBothDirections() throws {
    #expect(HijriMonth(year: 1447, month: 12).shifted(1) == .init(year: 1448, month: 1))
    #expect(HijriMonth(year: 1448, month: 1).shifted(-1) == .init(year: 1447, month: 12))
    #expect(HijriMonth(year: 1448, month: -12) == .init(year: 1446, month: 12))
    let cal = try F.calendar()
    #expect(cal.date(year: 1447, month: 13, day: 1) == F.date(6, 16))
    #expect(cal.date(year: 1448, month: 0, day: 10) == F.date(5, 27))
  }

  @Test func roundTripsAll365DiyanetDaysAndRNCacheShape() throws {
    let cache = try F.cache(), cal = ReligiousCalendar(cache: cache, calendar: F.clock)
    #expect(cache.days.count == 365)
    for (iso, parts) in cache.days {
      let date = try #require(NotificationPlan.parseDay(iso, calendar: F.clock))
      let h = HijriDate(year: parts[0], month: parts[1], day: parts[2])
      #expect(cal.hijri(date) == h)
      #expect(cal.date(year: h.year, month: h.month, day: h.day) == date)
    }
    let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(cache)) as! [String: Any]
    #expect(Set(json.keys) == ["year", "fetchedAt", "days"])
    #expect((json["days"] as? [String: [Int]])?["2026-02-19"] == [1447, 9, 1])
  }

  @Test func ramadanUsesOfficialLengthAndMondayFirstGrid() throws {
    let grid = HijriMonthGrid(month: .init(year: 1447, month: 9), calendar: try F.calendar())
    #expect(grid.start == F.date(2, 19))
    #expect(grid.dayCount == 29 && grid.firstWeekday == 3)
    #expect(grid.cells.count == 35 && grid.cells.prefix(3).allSatisfy { $0 == nil })
    #expect(grid.cells.compactMap { $0 } == Array(1...29))
    #expect(grid.cells[4] == 2) // Cuma sütunu = 4.
  }

  @Test func yearEndUsesNextYearsExactCachedStart() throws {
    let cal = try F.calendar()
    let end = HijriMonthGrid(month: .init(year: 1447, month: 12), calendar: cal)
    #expect(end.start == F.date(5, 18) && end.dayCount == 29)
    let first = HijriMonthGrid(month: end.month.shifted(1), calendar: cal)
    #expect(first.start == F.date(6, 16) && first.firstWeekday == 1)
    for month in 8...12 {
      let grid = HijriMonthGrid(month: .init(year: 1447, month: month), calendar: cal)
      #expect((29...30).contains(grid.dayCount))
      #expect(grid.cells.count % 7 == 0)
    }
  }

  @Test func matchesRNSpecialDayMappingForRamadanAndEid() throws {
    let cal = try F.calendar(), events = cal.religiousDays(now: F.date(2, 19))
    let ramadan = HijriMonthGrid(month: .init(year: 1447, month: 9), calendar: cal).events(events)
    #expect(ramadan.keys.sorted() == [1, 26, 29])
    #expect(ramadan[1]?.id == "ramazan_start_1447")
    #expect(ramadan[29]?.id == "ramazan_bayram_arife_1447")
    let shawwal = HijriMonthGrid(month: .init(year: 1447, month: 10), calendar: cal).events(events)
    #expect(shawwal.keys.sorted() == [1, 2, 3])
    #expect(shawwal[1]?.date == F.date(3, 20))
  }

  @Test func countdownUsesLocalDatesAcrossDSTAndTodayIsZero() {
    var london = Calendar(identifier: .gregorian)
    london.timeZone = TimeZone(identifier: "Europe/London")!
    let fall = london.date(from: .init(year: 2026, month: 10, day: 25))!
    let tomorrow = london.date(byAdding: .day, value: 1, to: fall)!
    #expect(tomorrow.timeIntervalSince(fall) == 25 * 3600)
    #expect(HijriCalendarText.daysLeft(until: tomorrow, now: fall, calendar: london) == 1)
    #expect(HijriCalendarText.daysLeft(until: fall, now: fall.addingTimeInterval(12 * 3600), calendar: london) == 0)
    let spring = london.date(from: .init(year: 2026, month: 3, day: 29))!
    let next = london.date(byAdding: .day, value: 1, to: spring)!
    #expect(next.timeIntervalSince(spring) == 23 * 3600)
    #expect(HijriCalendarText.daysLeft(until: next, now: spring, calendar: london) == 1)
  }

  @Test func malformedHijriCacheEntriesCannotShiftValidData() {
    let cache = ReligiousCalendar.Cache(year: 2026, fetchedAt: 0, days: [
      "2026-02-19": [1447, 9, 1], "2026-12-31": [1448, 99, 4],
      "2026-12-30": [Int.max, 1, 1], "2026-12-29": [1448, 1, -1], "bad": [1448, 1],
    ])
    let cal = ReligiousCalendar(cache: cache, calendar: F.clock)
    #expect(cal.hijri(F.date(2, 20)) == .init(year: 1447, month: 9, day: 2))
  }
}

@MainActor
struct HijriCalendarStoreTests {
  typealias F = HijriCalendarFixture

  @Test func showsSixUpcomingIncludingTodayInDateOrder() throws {
    let cal = try F.calendar()
    let store = HijriCalendarStore(initial: cal, now: { F.date(2, 19, hour: 12) }, load: { _ in cal })
    #expect(store.today == .init(year: 1447, month: 9, day: 1))
    #expect(store.upcoming.count == 6 && store.upcoming.first?.id == "ramazan_start_1447")
    #expect(store.upcoming.allSatisfy { $0.date >= F.date(2, 19) })
    #expect(store.upcoming.map(\.date) == store.upcoming.map(\.date).sorted())
    store.move(1)
    #expect(!store.isViewingToday && store.viewMonth == .init(year: 1447, month: 10))
    store.goToday()
    #expect(store.isViewingToday)
  }

  @Test func midnightFollowsTodayButPreservesBrowsedMonth() throws {
    let cal = try F.calendar()
    var clock = F.date(3, 19, hour: 23, minute: 59)
    let store = HijriCalendarStore(initial: cal, now: { clock }, load: { _ in cal })
    #expect(store.viewMonth == .init(year: 1447, month: 9))
    clock = F.date(3, 20, minute: 1)
    store.updateClock()
    #expect(store.today.day == 1 && store.viewMonth.month == 10)
    store.move(-2)
    clock = F.date(4, 20)
    store.updateClock()
    #expect(store.viewMonth == .init(year: 1447, month: 8))
  }

  @Test func freshCalibrationMovesTodayToTheCorrectMonth() async throws {
    let stale = ReligiousCalendar(cache: .init(year: 2026, fetchedAt: 0, days: ["2026-02-19": [1447, 8, 29]]), calendar: F.clock)
    let fresh = try F.calendar()
    let store = HijriCalendarStore(initial: stale, now: { F.date(2, 19) }, load: { _ in fresh })
    #expect(store.viewMonth.month == 8)
    await store.refresh()
    #expect(store.viewMonth.month == 9 && store.today.day == 1)
  }

  @Test func lateLoadPreservesNavigation() async throws {
    let stale = ReligiousCalendar(cache: .init(year: 2026, fetchedAt: 0, days: ["2026-02-19": [1447, 8, 29]]), calendar: F.clock)
    let fresh = try F.calendar()
    var instance: HijriCalendarStore?
    let store = HijriCalendarStore(initial: stale, now: { F.date(2, 19) }, load: { _ in
      instance?.move(2)
      await Task.yield()
      return fresh
    })
    instance = store
    await store.refresh()
    #expect(store.viewMonth == .init(year: 1447, month: 10))
    #expect(store.today == .init(year: 1447, month: 9, day: 1))
    instance = nil
  }

  @Test func newerRefreshWinsWhenResponsesArriveOutOfOrder() async throws {
    let stale = ReligiousCalendar(calendar: F.clock), fresh = try F.calendar()
    var calls = 0
    let store = HijriCalendarStore(initial: stale, now: { F.date(2, 19) }, load: { _ in
      calls += 1
      if calls == 1 { try? await Task.sleep(for: .milliseconds(30)); return stale }
      return fresh
    })
    let first = Task { await store.refresh() }
    while calls == 0 { await Task.yield() }
    await store.refresh()
    await first.value
    #expect(store.today == .init(year: 1447, month: 9, day: 1))
  }
}

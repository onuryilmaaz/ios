import Foundation
import Testing
@testable import Salah

/// RN'deki src/services/__tests__/prayerWindow.test.ts ile aynı girdiler ve beklentiler.
@MainActor
struct PrayerWindowTests {
  let times = PrayerTimes(imsak: "05:25", gunes: "06:49", ogle: "12:55", ikindi: "16:13", aksam: "18:51", yatsi: "20:10")

  /// 1 Ekim 2026, yerel saat.
  func at(_ hhmm: String) -> Date {
    let p = hhmm.split(separator: ":").compactMap { Int($0) }
    return Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: p[0], minute: p[1]))!
  }

  func day(_ date: Date) -> Int { Calendar.current.component(.day, from: date) }

  @Test(arguments: [
    ("03:00", PrayerWindow.Mode.current, "Yatsı", "05:25"),
    ("05:30", .current, "Sabah", "06:49"),
    ("09:00", .upcoming, "Öğle", "12:55"),
    ("13:00", .current, "Öğle", "16:13"),
    ("17:00", .current, "İkindi", "18:51"),
    ("19:00", .current, "Akşam", "20:10"),
    ("23:00", .current, "Yatsı", "05:25"),
  ])
  func window(now: String, mode: PrayerWindow.Mode, name: String, end: String) {
    let w = PrayerWindow.compute(times, completed: [], now: at(now))
    #expect(w.mode == mode)
    #expect(w.prayerName == name)
    #expect(formatHHMM(w.end) == end)
  }

  @Test func afterMidnightYatsiStartsPreviousDay() {
    let w = PrayerWindow.compute(times, completed: [], now: at("01:00"))
    #expect(day(w.start!) == 30)
    #expect(formatHHMM(w.start!) == "20:10")
  }

  @Test func lateYatsiEndsNextImsak() {
    let w = PrayerWindow.compute(times, completed: [], now: at("23:00"))
    #expect(day(w.end) == 2)
  }

  @Test func fajrDoneSkipsSunriseToDhuhr() {
    let w = PrayerWindow.compute(times, completed: ["fajr"], now: at("05:40"))
    #expect(w.mode == .upcoming)
    #expect(w.prayerName == "Öğle")
    #expect(formatHHMM(w.end) == "12:55")
  }

  @Test(arguments: [
    ("13:00", "dhuhr", "İkindi"),
    ("17:00", "asr", "Akşam"),
    ("19:00", "maghrib", "Yatsı"),
    ("23:00", "isha", "Sabah"),
  ])
  func completedCountsToNext(now: String, done: String, next: String) {
    let w = PrayerWindow.compute(times, completed: [done], now: at(now))
    #expect(w.mode == .upcoming)
    #expect(w.prayerName == next)
    #expect(w.start == nil)
  }

  @Test func otherCompletedPrayerDoesNotChangeCurrent() {
    let w = PrayerWindow.compute(times, completed: ["fajr"], now: at("17:00"))
    #expect(w.mode == .current)
    #expect(w.prayerName == "İkindi")
  }

  @Test func islamicDayRollsOverAtFour() {
    #expect(islamicDateString(at("03:59")) == "2026-09-30")
    #expect(islamicDateString(at("04:00")) == "2026-10-01")
  }
}

/// RN'deki buildPrayerTimeline testleri.
@MainActor
struct PrayerTimelineTests {
  let times = PrayerTimes(imsak: "05:25", gunes: "06:49", ogle: "12:55", ikindi: "16:13", aksam: "18:51", yatsi: "20:10")

  func at(_ hhmm: String) -> Date {
    let p = hhmm.split(separator: ":").compactMap { Int($0) }
    return Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: p[0], minute: p[1]))!
  }

  @Test func afternoonTransitionsInOrder() {
    let tl = PrayerWindow.timeline(times, completed: [], now: at("13:00"))
    #expect(tl.map { "\(formatHHMM($0.at)) \($0.window.prayerName) \($0.window.mode.rawValue)" } == [
      "16:13 İkindi current", "18:51 Akşam current", "20:10 Yatsı current",
    ])
  }

  @Test func transitionAtPreviousEndStateIsNext() {
    let tl = PrayerWindow.timeline(times, completed: [], now: at("17:00"))
    #expect(formatHHMM(tl[0].at) == "18:51")
    #expect(formatHHMM(tl[0].window.end) == "20:10")
  }

  @Test func overnightIncludesFajrAndWaitForDhuhr() {
    let tl = PrayerWindow.timeline(times, completed: [], now: at("23:00"))
    #expect(tl.map(\.window.prayerName) == ["Sabah", "Öğle"])
    #expect(tl[1].window.mode == .upcoming)
  }

  @Test func completedResetsAtNewPrayerDay() {
    let tl = PrayerWindow.timeline(times, completed: ["isha", "fajr"], now: at("23:00"))
    #expect(tl[0].window.prayerName == "Sabah")
    #expect(tl[0].window.mode == .current)
  }
}

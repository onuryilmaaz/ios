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

/// Geçmiş ekranı: vakti girmemiş namaz işaretlenemez.
@MainActor
struct PrayerSlotGateTests {
  let times = PrayerTimes(imsak: "05:25", gunes: "06:49", ogle: "12:55", ikindi: "16:13", aksam: "18:51", yatsi: "20:10")

  func at(_ day: Int, _ hhmm: String) -> Date {
    let p = hhmm.split(separator: ":").compactMap { Int($0) }
    return Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day, hour: p[0], minute: p[1]))!
  }

  @Test(arguments: [
    ("fajr", false), ("dhuhr", false), ("asr", true), ("maghrib", true), ("isha", true),
  ])
  func todayBeforeTimeIsLocked(_ id: String, _ locked: Bool) {
    #expect(PrayerSlotGate.notYet(id, day: at(1, "00:00"), now: at(1, "13:30"), times: times) == locked)
  }

  @Test func unlocksExactlyAtTime() {
    #expect(PrayerSlotGate.notYet("asr", day: at(1, "00:00"), now: at(1, "16:12"), times: times))
    #expect(!PrayerSlotGate.notYet("asr", day: at(1, "00:00"), now: at(1, "16:13"), times: times))
  }

  @Test func pastDayIsOpen() {
    #expect(!PrayerSlotGate.notYet("isha", day: at(1, "00:00"), now: at(2, "06:00"), times: times))
  }

  @Test func futureDayIsLocked() {
    #expect(PrayerSlotGate.notYet("fajr", day: at(2, "00:00"), now: at(1, "23:00"), times: times))
  }

  @Test func unknownTimesStayOpen() {
    #expect(!PrayerSlotGate.notYet("isha", day: at(1, "00:00"), now: at(1, "08:00"), times: nil))
  }
}

/// Takip kartı ve Siri "Kıldım" ortak kuralı.
@MainActor
struct PrayerSlotStateTests {
  let times = PrayerTimes(imsak: "05:25", gunes: "06:49", ogle: "12:55", ikindi: "16:13", aksam: "18:51", yatsi: "20:10")

  func at(_ hhmm: String) -> Date {
    let p = hhmm.split(separator: ":").compactMap { Int($0) }
    return Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: p[0], minute: p[1]))!
  }

  @Test(arguments: [
    ("fajr", "06:00", PrayerSlotState.current), ("fajr", "07:00", .expired), ("dhuhr", "12:00", .upcoming),
    ("asr", "16:13", .current), ("maghrib", "20:10", .expired), ("isha", "23:30", .current),
    // Gece yarısından sonra: yatsı hâlâ kılınabilir, diğerleri kaza.
    ("isha", "02:00", .current), ("asr", "02:00", .expired),
    // 04:00–imsak: yeni namaz günü, hiçbir vakit işaretlenemez.
    ("isha", "04:30", .upcoming), ("fajr", "04:30", .upcoming),
  ])
  func state(_ id: String, _ hhmm: String, _ expected: PrayerSlotState) {
    #expect(PrayerSlotState.of(id, times: times, now: at(hhmm)) == expected)
  }

  @Test func remainingRoundsUpToMinutes() {
    Localizer.shared.setPreference(.fixed(.en))
    defer { Localizer.shared.setPreference(.system) }
    #expect(SiriPrayer.remaining(from: at("12:00"), to: at("13:05")) == "1 hour, 5 minutes")
    #expect(SiriPrayer.remaining(from: at("12:00"), to: at("12:00").addingTimeInterval(30)) == "1 minute")
  }
}

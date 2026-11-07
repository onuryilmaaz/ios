import Foundation
import Testing
@testable import Salah

struct RamadanPlanTests {
  private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Istanbul")!; return c }
  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))! }
  private var times: PrayerTimes { PrayerTimes(imsak: "05:30", gunes: "07:00", ogle: "13:00", ikindi: "16:00", aksam: "18:30", yatsi: "20:00") }
  private var window: RamadanWindow { .init(hijriYear: 1448, start: date(2027, 2, 8), last: date(2027, 3, 8), days: 29) }

  @Test func modeFollowsCalendarExceptForAdmin() {
    let far = date(2026, 11, 7, 12), during = date(2027, 2, 12, 12)
    #expect(!RamadanPlan.isModeOn(admin: false, real: window, now: far, calendar: cal))
    #expect(RamadanPlan.isModeOn(admin: false, real: window, now: during, calendar: cal))
    #expect(RamadanPlan.isModeOn(admin: true, real: window, now: far, calendar: cal))
    #expect(RamadanPlan.isModeOn(admin: true, real: window, now: during, calendar: cal))
  }

  @Test func previewOnlyForAdminOutsideRamadan() {
    let far = date(2026, 11, 7, 12), during = date(2027, 2, 12, 12)
    #expect(RamadanPlan.usesPreview(admin: true, real: window, now: far, calendar: cal))
    #expect(!RamadanPlan.usesPreview(admin: true, real: window, now: during, calendar: cal))
    #expect(!RamadanPlan.usesPreview(admin: false, real: window, now: far, calendar: cal))
    let preview = RamadanPlan.previewWindow(now: far, calendar: cal)
    #expect(RamadanPlan.phase(preview, now: far, today: times, tomorrow: times, calendar: cal) ==
      .active(day: 5, total: 29, countdown: .init(kind: .iftar, target: date(2026, 11, 7, 18, 30))))
  }

  @Test func previewImsakiyeUsesExactDatesWithoutHijriFilter() {
    // PrayerDay.localDay cihaz saat dilimini kullanır.
    let c = Calendar.current
    let base = c.startOfDay(for: date(2026, 11, 3, 12))
    let preview = RamadanPlan.previewWindow(now: c.date(byAdding: .day, value: 4, to: base)!, calendar: c)
    let all = (-10..<40).map { offset in
      PrayerDay(date: ISO8601DateFormatter().string(from: c.date(byAdding: .hour, value: offset * 24 + 12, to: base)!), times: times, hijri_date: .init(month: 5))
    }
    #expect(RamadanPlan.imsakiye(all, window: preview, calendar: c).count == 29)
    #expect(RamadanPlan.imsakiye(all, window: window, calendar: c).isEmpty)
  }

  @Test func ledgerKeepsPendingUntilServerConfirms() {
    let marked = RamadanLedger().marking(1448, day: "2027-02-08", fasted: true).marking(1448, day: "2027-02-09", fasted: true)
    #expect(marked.days(1448) == ["2027-02-08", "2027-02-09"])
    // İstek sürerken 09'u geri aldı: sunucu yanıtı bu değişikliği ezmemeli.
    let sent = marked.pending["1448"]!
    let changed = marked.marking(1448, day: "2027-02-09", fasted: false)
    let merged = changed.merged(1448, sent: sent, sentKaza: 0, serverDays: ["2027-02-08", "2027-02-09", "2027-02-10"], serverKaza: 0)
    #expect(merged.days(1448) == ["2027-02-08", "2027-02-10"])
    #expect(merged.pending["1448"] == ["2027-02-09": false])
    #expect(changed.merged(1448, sent: changed.pending["1448"]!, sentKaza: 0, serverDays: ["2027-02-08"], serverKaza: 0).pending.isEmpty)
  }

  @Test func previewMarksNeverWaitForServer() {
    let marked = RamadanLedger().marking(RamadanPlan.previewHijriYear, day: "2026-11-07", fasted: true)
    #expect(marked.days(RamadanPlan.previewHijriYear).count == 1)
    #expect(marked.pending.isEmpty)
  }

  @Test func kazaAppliesAsDeltaAndStopsAtZero() {
    var start = RamadanLedger(); start.kaza = 1
    let up = start.addingKaza(1).addingKaza(1)
    #expect(up.kaza == 3 && up.kazaPending == 2)
    let down = start.addingKaza(-1).addingKaza(-1)
    #expect(down.kaza == 0 && down.kazaPending == -1)
    // Başka cihaz sayacı 5 yapmış, istek sırasında bir artış daha gelmiş.
    let merged = up.addingKaza(1).merged(1448, sent: [:], sentKaza: 2, serverDays: [], serverKaza: 5)
    #expect(merged.kaza == 6 && merged.kazaPending == 1)
  }

  @Test func iftarMomentOncePerDayAfterSunset() {
    #expect(!RamadanPlan.iftarMomentDue(window, now: date(2027, 2, 12, 18, 29), today: times, shownDay: nil, calendar: cal))
    #expect(RamadanPlan.iftarMomentDue(window, now: date(2027, 2, 12, 18, 30), today: times, shownDay: nil, calendar: cal))
    #expect(RamadanPlan.iftarMomentDue(window, now: date(2027, 2, 12, 23), today: times, shownDay: "2027-02-11", calendar: cal))
    #expect(!RamadanPlan.iftarMomentDue(window, now: date(2027, 2, 12, 23), today: times, shownDay: "2027-02-12", calendar: cal))
    #expect(!RamadanPlan.iftarMomentDue(window, now: date(2027, 2, 7, 19), today: times, shownDay: nil, calendar: cal))
    #expect(!RamadanPlan.iftarMomentDue(window, now: date(2027, 3, 9, 19), today: times, shownDay: nil, calendar: cal))
    #expect(!RamadanPlan.iftarMomentDue(window, now: date(2027, 2, 12, 19), today: nil, shownDay: nil, calendar: cal))
  }

  @Test func kadirNightCountsToDay26() {
    #expect(RamadanPlan.kadirDaysLeft(window, now: date(2027, 2, 12), calendar: cal) == 21)
    #expect(RamadanPlan.kadirDaysLeft(window, now: date(2027, 3, 5), calendar: cal) == 0)
    #expect(RamadanPlan.kadirDaysLeft(window, now: date(2027, 3, 6), calendar: cal) == nil)
  }

  @Test func moonGrowsThenShrinksOnTheOtherSide() {
    #expect(RamadanMoon.illumination(day: 5) < RamadanMoon.illumination(day: 10))
    #expect(RamadanMoon.illumination(day: 15) > 0.95)
    #expect(RamadanMoon.illumination(day: 28) < 0.2)
    #expect(RamadanMoon.outline(day: 5)[14].x > 0)
    #expect(RamadanMoon.outline(day: 25)[14].x < 0)
  }

  @Test func tintFollowsTheDay() {
    #expect(RamadanPlan.tint(now: date(2027, 2, 12, 5, 29), today: times, calendar: cal) == .night)
    #expect(RamadanPlan.tint(now: date(2027, 2, 12, 5, 30), today: times, calendar: cal) == .dawn)
    #expect(RamadanPlan.tint(now: date(2027, 2, 12, 13), today: times, calendar: cal) == .dusk)
    #expect(RamadanPlan.tint(now: date(2027, 2, 12, 18, 30), today: times, calendar: cal) == .night)
    #expect(RamadanPlan.tint(now: date(2027, 2, 12, 13), today: nil, calendar: cal) == .night)
  }

  @Test func qiblaThemeFallsBackToForest() {
    #expect(QiblaTheme.all.count == 5)
    #expect(Set(QiblaTheme.all.map(\.id)).count == 5)
    #expect(QiblaTheme.find("dusk").motif == .mihrab)
    #expect(QiblaTheme.find("yok").id == "forest")
    #expect(QiblaTheme.find(nil).id == "forest")
  }

  @Test func appControlFollowsScheduleAndFailsOpen() {
    let date = { (text: String) in AppControlLogic.date(text)! }
    #expect(AppControlLogic.isOn(nil, now: Date()))
    let closure = AppControlLogic.ModuleState(enabled: true, schedule: .init(from: "2027-01-01T10:00:00.000Z", to: "2027-01-01T12:00:00.000Z", enabled: false))
    #expect(AppControlLogic.isOn(closure, now: date("2027-01-01T09:00:00Z")))
    #expect(!AppControlLogic.isOn(closure, now: date("2027-01-01T11:00:00Z")))
    #expect(AppControlLogic.isOn(closure, now: date("2027-01-01T12:00:00Z")))
    let open = AppControlLogic.ModuleState(enabled: true, schedule: .init(from: "2027-01-01T10:00:00Z", to: nil, enabled: false))
    #expect(!AppControlLogic.isOn(open, now: date("2030-01-01T00:00:00Z")))
  }

  @Test func announcementsRespectPlatformWindowAndSeen() {
    let item = AppControlLogic.Announcement(id: "a", title: ["tr": "B"], body: ["tr": "M", "en": " "], kind: "info", platforms: ["ios"], frequency: "once", startsAt: "2027-01-01T00:00:00Z", endsAt: "2027-01-03T00:00:00Z")
    let inside = AppControlLogic.date("2027-01-02T00:00:00Z")!
    #expect(AppControlLogic.next([item], platform: "ios", now: inside, seen: [])?.id == "a")
    #expect(AppControlLogic.next([item], platform: "android", now: inside, seen: []) == nil)
    #expect(AppControlLogic.next([item], platform: "ios", now: inside, seen: ["a"]) == nil)
    #expect(AppControlLogic.next([item], platform: "ios", now: AppControlLogic.date("2027-01-04T00:00:00Z")!, seen: []) == nil)
    #expect(AppControlLogic.text(item.body, language: "en") == "M")
    #expect(AppControlLogic.isAllowedLink("salah://qibla") && !AppControlLogic.isAllowedLink("http://x"))
  }

  @Test func amountParsingAcceptsLocalFormats() {
    #expect(ZakatCalc.parseAmount("1.250") == 1250)
    #expect(ZakatCalc.parseAmount("1,250") == 1250)
    #expect(ZakatCalc.parseAmount("1.250,50") == 1250.5)
    #expect(ZakatCalc.parseAmount("1,250.50") == 1250.5)
    #expect(ZakatCalc.parseAmount("1.250.000") == 1_250_000)
    #expect(ZakatCalc.parseAmount("6250,75") == 6250.75)
    #expect(ZakatCalc.parseAmount("0,500") == 0.5)
    #expect(ZakatCalc.parseAmount("12.500", grouped: false) == 12.5)
    #expect(ZakatCalc.parseAmount("١٢٥٠") == 1250)
    #expect(ZakatCalc.parseAmount("") == 0)
    #expect(ZakatCalc.parseAmount("abc") == 0)
  }

  @MainActor @Test func juzPagesCoverTheWholeMushaf() {
    #expect(HatimGroupAPI.pages(ofJuz: 1) == 1...21)
    #expect(HatimGroupAPI.pages(ofJuz: 7) == 121...141)
    #expect(HatimGroupAPI.pages(ofJuz: 30) == 582...604)
  }

  @Test func dailyVerseCoversEveryDay() {
    #expect(RamadanPlan.dailyVerse(day: 1) == (2, 183))
    #expect(RamadanPlan.dailyVerse(day: 26) == (97, 1))
    #expect(RamadanPlan.dailyVerse(day: 30) == (73, 4))
    #expect(Set(RamadanPlan.dailyVerses.map { "\($0.surah):\($0.verse)" }).count == 30)
  }

  @Test func lastNightsAndKadir() {
    let nights = RamadanPlan.lastNights(window, calendar: cal)
    #expect(nights.count == 10)
    #expect(nights.first == date(2027, 2, 27))
    #expect(nights.last == date(2027, 3, 8))
    #expect(RamadanPlan.kadirDate(window, calendar: cal) == date(2027, 3, 5))
  }

  @Test func unmarkedSkipsTodayAndFuture() {
    #expect(RamadanPlan.unmarkedDays(window, now: date(2027, 2, 12, 9), marked: ["2027-02-09"], calendar: cal) == ["2027-02-08", "2027-02-10", "2027-02-11"])
    #expect(RamadanPlan.unmarkedDays(window, now: date(2027, 2, 1), marked: [], calendar: cal).isEmpty)
  }

  @Test func marksWaitUntilServerConfirms() {
    let marked = RamadanLedger().settingMark(1448, kind: "taraweeh", day: "2027-02-08", on: true)
    let old = marked.merged(1448, sent: [:], sentKaza: 0, serverDays: [], serverKaza: 0, sentMarks: marked.pendingMarks["1448"]!, serverMarks: nil)
    #expect(old.markDays(1448, kind: "taraweeh") == ["2027-02-08"])
    #expect(old.pendingMarks["1448"]?.count == 1)
    let fresh = marked.merged(1448, sent: [:], sentKaza: 0, serverDays: [], serverKaza: 0, sentMarks: marked.pendingMarks["1448"]!, serverMarks: ["taraweeh": ["2027-02-08"], "night": ["2027-03-05"]], serverOzelGun: ["2027-02-10"])
    #expect(fresh.pendingMarks.isEmpty)
    #expect(fresh.markDays(1448, kind: "night") == ["2027-03-05"])
    #expect(fresh.ozelGun["1448"] == ["2027-02-10"])
  }

  @Test func kazaAppliedOncePerDay() {
    let once = RamadanLedger().applyingKaza(1448, days: ["2027-02-08", "2027-02-09"])
    #expect(once.kaza == 2 && once.kazaPending == 2)
    #expect(once.applyingKaza(1448, days: ["2027-02-09", "2027-02-10"]).kaza == 3)
    let preview = RamadanLedger().applyingKaza(RamadanPlan.previewHijriYear, days: ["2026-11-03"])
    #expect(preview.kaza == 1 && preview.kazaPending == 0 && preview.pendingMarks.isEmpty)
  }

  @Test func oldLedgerStillDecodes() throws {
    let json = #"{"fasts":{"1448":["2027-02-08"]},"pending":{},"kaza":2,"kazaPending":1}"#
    let ledger = try JSONDecoder().decode(RamadanLedger.self, from: Data(json.utf8))
    #expect(ledger.kaza == 2 && ledger.marks.isEmpty)
  }

  @Test func countdownStepsAlternateAndStopAfterLastDay() {
    let steps = RamadanPlan.countdownSteps(window, now: date(2027, 2, 12, 4), calendar: cal) { _ in times }
    #expect(steps[0].kind == .sahur && steps[0].target == date(2027, 2, 12, 5, 30))
    #expect(steps[1].kind == .iftar && steps[1].target == date(2027, 2, 12, 18, 30))
    #expect(steps[2].kind == .sahur && steps[2].target == date(2027, 2, 13, 5, 30))
    #expect(RamadanPlan.countdownSteps(window, now: date(2027, 3, 8, 19), calendar: cal) { _ in times }.isEmpty)
    #expect(RamadanPlan.countdownSteps(window, now: date(2027, 1, 1, 12), calendar: cal) { _ in times }.isEmpty)
  }

  @Test func zakatFollowsNisabAndFortieth() {
    #expect(!ZakatCalc.compute(goldGrams: 10, goldPrice: 5000, cash: 0, trade: 0, receivable: 0, debt: 0).due)
    #expect(!ZakatCalc.compute(goldGrams: 100, goldPrice: 5000, cash: 100000, trade: 0, receivable: 0, debt: 200000).due)
    let paid = ZakatCalc.compute(goldGrams: 100, goldPrice: 5000, cash: 100000, trade: 0, receivable: 0, debt: 0)
    #expect(paid.due && paid.amount == 15000)
    #expect(!ZakatCalc.compute(goldGrams: 100, goldPrice: 0, cash: 1000000, trade: 0, receivable: 0, debt: 0).due)
  }

  @Test func hiddenFarAhead() {
    #expect(RamadanPlan.phase(window, now: date(2026, 11, 6), today: times, tomorrow: times, calendar: cal) == .none)
  }

  @Test func upcomingInsideLookahead() {
    #expect(RamadanPlan.phase(window, now: date(2027, 1, 9), today: times, tomorrow: times, calendar: cal) == .upcoming(daysLeft: 30, start: date(2027, 2, 8)))
    #expect(RamadanPlan.phase(window, now: date(2027, 1, 8), today: times, tomorrow: times, calendar: cal) == .none)
    #expect(RamadanPlan.phase(window, now: date(2027, 2, 7, 23), today: times, tomorrow: times, calendar: cal) == .upcoming(daysLeft: 1, start: date(2027, 2, 8)))
  }

  @Test func countdownFollowsTheDay() {
    #expect(RamadanPlan.phase(window, now: date(2027, 2, 12, 4), today: times, tomorrow: times, calendar: cal) ==
      .active(day: 5, total: 29, countdown: .init(kind: .sahur, target: date(2027, 2, 12, 5, 30))))
    #expect(RamadanPlan.phase(window, now: date(2027, 2, 12, 12), today: times, tomorrow: times, calendar: cal) ==
      .active(day: 5, total: 29, countdown: .init(kind: .iftar, target: date(2027, 2, 12, 18, 30))))
    #expect(RamadanPlan.phase(window, now: date(2027, 2, 12, 20), today: times, tomorrow: times, calendar: cal) ==
      .active(day: 5, total: 29, countdown: .init(kind: .sahur, target: date(2027, 2, 13, 5, 30))))
  }

  @Test func endsAfterLastIftar() {
    #expect(RamadanPlan.phase(window, now: date(2027, 3, 8, 12), today: times, tomorrow: times, calendar: cal) ==
      .active(day: 29, total: 29, countdown: .init(kind: .iftar, target: date(2027, 3, 8, 18, 30))))
    #expect(RamadanPlan.phase(window, now: date(2027, 3, 8, 19), today: times, tomorrow: times, calendar: cal) == .none)
    #expect(RamadanPlan.phase(window, now: date(2027, 3, 9, 9), today: times, tomorrow: times, calendar: cal) == .none)
  }

  @Test func missingTimesStillShowsTheDay() {
    #expect(RamadanPlan.phase(window, now: date(2027, 2, 8, 9), today: nil, tomorrow: nil, calendar: cal) == .active(day: 1, total: 29, countdown: nil))
  }

  @Test func windowMovesToNextYearAfterRamadan() {
    let religious = ReligiousCalendar(calendar: cal)
    let during = RamadanPlan.window(religious, now: date(2026, 3, 1), calendar: cal)
    let after = RamadanPlan.window(religious, now: date(2026, 11, 6), calendar: cal)
    #expect(during.hijriYear + 1 == after.hijriYear)
    #expect((29...30).contains(after.days))
    #expect(after.start > date(2026, 11, 6))
  }

  @Test func imsakiyeKeepsOnlyThisRamadan() {
    func day(_ iso: String, _ month: Int?) -> PrayerDay { PrayerDay(date: iso, times: times, hijri_date: .init(month: month)) }
    let result = RamadanPlan.imsakiye(
      [day("2027-02-09T12:00:00.000Z", 9), day("2027-02-08T12:00:00.000Z", 9), day("2027-02-07T12:00:00.000Z", 8), day("2027-05-08T12:00:00.000Z", 9)],
      window: window, calendar: cal)
    #expect(result.map(\.date) == ["2027-02-08T12:00:00.000Z", "2027-02-09T12:00:00.000Z"])
  }

  @Test func dailyPagesRoundUpAndCarryToday() {
    #expect(HatimPlan.dailyPages(pages: 604, daysLeft: 30) == 21)
    #expect(HatimPlan.dailyPages(pages: 0, daysLeft: 5) == 1)
    let plan = HatimPlan(targetDate: "2027-03-08", startHatims: 1, reminderHour: nil, reminderMinute: nil)
    // 600 kalan + bugün 4 okunmuş, 2 gün: hedef bugün okununca değişmez.
    let p = plan.progress(completedHatims: 1, currentPages: 4, pagesPerHatim: 604, todayRead: 4, today: date(2027, 3, 7), calendar: cal)
    #expect(p.dailyTarget == 302 && p.remaining == 600 && p.daysLeft == 2 && !p.finished && !p.overdue && !p.todayDone)
  }

  @Test func planFinishesAndExpires() {
    let plan = HatimPlan(targetDate: "2027-03-08", startHatims: 1, reminderHour: nil, reminderMinute: nil)
    #expect(plan.progress(completedHatims: 2, currentPages: 10, pagesPerHatim: 604, todayRead: 0, today: date(2027, 3, 1), calendar: cal).finished)
    #expect(plan.progress(completedHatims: 1, currentPages: 10, pagesPerHatim: 604, todayRead: 0, today: date(2027, 3, 9), calendar: cal).overdue)
  }

  @Test func reminderStopsAtTargetDay() {
    var p = NotificationPreferences(); p.enabled = true; p.inspiration = false; p.religiousDays = false; p.friday = false
    p.prayerEnabled = [:]
    let plan = NotificationPlan.build(days: [], preferences: p, now: date(2027, 3, 7, 8), calendar: cal,
                                      hatim: .init(hour: 21, minute: 0, dailyPages: 20, targetDate: "2027-03-08"))
    #expect(plan.filter { $0.kind == .hatim }.map(\.date) == [date(2027, 3, 7, 21), date(2027, 3, 8, 21)])
  }
}

struct UpdatePolicyTests {
  @Test func comparesNumerically() {
    #expect(UpdatePolicy.compare("1.0.10", "1.0.9") == 1)
    #expect(UpdatePolicy.compare("1.1", "1.1.0") == 0)
    #expect(UpdatePolicy.compare("1.1-beta", "1.1") == 0)
    #expect(UpdatePolicy.compare("", "0.0.1") == -1)
  }

  @Test func requiredWinsOverOptional() {
    let server = UpdatePolicy.Server(minVersion: "1.0.5", latestVersion: "1.0.6", storeUrl: "https://x")
    #expect(UpdatePolicy.evaluate(current: "1.0.4", server) == .required(storeURL: "https://x"))
    #expect(UpdatePolicy.evaluate(current: "1.0.5", server) == .optional(version: "1.0.6", storeURL: "https://x"))
    #expect(UpdatePolicy.evaluate(current: "1.0.6", server) == .none)
  }

  @Test func emptyPolicyDoesNothing() {
    #expect(UpdatePolicy.evaluate(current: "1.0.0", .init(minVersion: nil, latestVersion: "", storeUrl: nil)) == .none)
    #expect(UpdatePolicy.evaluate(current: "1.0.0", .init(minVersion: nil, latestVersion: "2.0", storeUrl: "")) == .optional(version: "2.0", storeURL: UpdatePolicy.defaultStoreURL))
  }
}

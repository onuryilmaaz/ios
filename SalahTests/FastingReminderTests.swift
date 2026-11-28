import Foundation
import Testing
@testable import Salah

/// Nafile oruç günleri: saf fonksiyon (`FastingReminder.fastingDays`) ve bildirim planına bağlanışı.
@MainActor
struct FastingReminderTests {
  private var cal: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return cal
  }
  private func day(_ month: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: month, day: day))! }
  /// Ayın gününü Hicri gün gibi kullanan sahte takvim (gün numarası kontrol altında).
  private func hijri(month: Int, shift: Int = 0) -> (Date) -> HijriDate {
    { HijriDate(year: 1448, month: month, day: cal.component(.day, from: $0) + shift) }
  }
  private func run(from: Date, days: Int, _ hijri: @escaping (Date) -> HijriDate, _ enabled: Set<FastingGroup> = Set(FastingGroup.allCases)) -> [FastingDay] {
    FastingReminder.fastingDays(from: from, days: days, hijri: hijri, enabled: enabled, calendar: cal)
  }

  @Test func mondayAndThursday() {
    // 23 Kasım 2026 pazartesi, 26 perşembe.
    let result = run(from: day(11, 23), days: 7, { _ in HijriDate(year: 1448, month: 5, day: 1) })
    #expect(result == [FastingDay(date: day(11, 23), kind: .monday), FastingDay(date: day(11, 26), kind: .thursday)])
  }

  @Test func weeklyOffMeansNoWeekdays() {
    #expect(run(from: day(11, 23), days: 7, { _ in HijriDate(year: 1448, month: 5, day: 1) }, [.ashura]).isEmpty)
    #expect(run(from: day(11, 23), days: 7, { _ in HijriDate(year: 1448, month: 5, day: 1) }, []).isEmpty)
  }

  @Test func ayyamBid() {
    // Hicri gün 13, 14, 15 = 13, 14, 15 Kasım.
    let result = run(from: day(11, 10), days: 7, hijri(month: 5), [.ayyamBid])
    #expect(result.map(\.date) == [day(11, 13), day(11, 14), day(11, 15)])
    #expect(result.allSatisfy { $0.kind == .ayyamBid })
  }

  @Test func ashuraCoversTwoDays() {
    let result = run(from: day(11, 7), days: 5, hijri(month: 1), [.ashura])
    #expect(result == [FastingDay(date: day(11, 9), kind: .ashura), FastingDay(date: day(11, 10), kind: .ashura)])
  }

  @Test func arafahOnlyZilhiccce9() {
    // 9 Kasım pazartesi: Arefe, pazartesiden önce gelir. 10 ve sonrası bayram günleri.
    let result = run(from: day(11, 8), days: 4, hijri(month: 12))
    #expect(result == [FastingDay(date: day(11, 9), kind: .arafah)])
  }

  @Test func ramadanIsExcluded() {
    #expect(run(from: day(11, 1), days: 30, hijri(month: 9)).isEmpty)
    // Gerçek hesap: 1448 Ramazan'ının tamamı.
    let start = HijriMath.date(HijriMath.julian(1448, 9, 1), calendar: cal)
    #expect(run(from: start, days: 29, { HijriMath.hijri(HijriMath.julian(date: $0, calendar: cal)) }).isEmpty)
  }

  @Test func firstOfShawwalIsExcluded() {
    // 2 Kasım pazartesi = 1 Şevval; 5 Kasım perşembe = 4 Şevval.
    let result = run(from: day(11, 2), days: 5, hijri(month: 10, shift: -1))
    #expect(result == [FastingDay(date: day(11, 5), kind: .thursday)])
  }

  @Test func zilhiccce13IsDroppedFromAyyamBid() {
    // 13 Zilhicce eyyâm-ı bîzden düşer; 14 ve 15 kalır.
    let result = run(from: day(11, 12), days: 4, hijri(month: 12), [.ayyamBid])
    #expect(result.map(\.date) == [day(11, 14), day(11, 15)])
    #expect(FastingReminder.isExcluded(.init(year: 1448, month: 12, day: 10)))
    #expect(FastingReminder.isExcluded(.init(year: 1448, month: 12, day: 13)))
    #expect(!FastingReminder.isExcluded(.init(year: 1448, month: 12, day: 9)))
  }

  @Test func overlapKeepsOneEntryWithPriority() {
    // 23 Kasım pazartesi: Hicri 10 Muharrem (Aşure) pazartesiden önce gelir.
    #expect(run(from: day(11, 23), days: 1, { _ in HijriDate(year: 1448, month: 1, day: 10) }) == [FastingDay(date: day(11, 23), kind: .ashura)])
    // Pazartesi + 14. gün: eyyâm-ı bîz.
    #expect(run(from: day(11, 23), days: 1, { _ in HijriDate(year: 1448, month: 5, day: 14) }) == [FastingDay(date: day(11, 23), kind: .ayyamBid)])
    // Perşembe + Arefe: Arefe.
    #expect(run(from: day(11, 26), days: 1, { _ in HijriDate(year: 1448, month: 12, day: 9) }) == [FastingDay(date: day(11, 26), kind: .arafah)])
  }

  @Test func horizonIsExact() {
    #expect(run(from: day(11, 23), days: 3, { _ in HijriDate(year: 1448, month: 5, day: 1) }).map(\.date) == [day(11, 23)])
    #expect(run(from: day(11, 23), days: 0, { _ in HijriDate(year: 1448, month: 5, day: 1) }).isEmpty)
  }
}

@MainActor
struct FastingPlanTests {
  private var cal: Calendar { NotificationFixtures.calendar }

  @Test func eveningReminderAt21AndSuhoorBeforeImsak() {
    var p = NotificationFixtures.enabled
    p.fasting = true
    p.fastingSuhoor = true
    // 21 Ekim (Çarşamba) için nafile oruç günü.
    let fast = [FastingDay(date: cal.startOfDay(for: NotificationFixtures.date(21)), kind: .thursday)]
    let plan = NotificationPlan.build(days: NotificationFixtures.days, preferences: p, now: NotificationFixtures.date(19, 10), calendar: cal, fasting: fast)
      .filter { $0.kind == .fasting }
    #expect(plan.count == 2)
    #expect(plan.first { $0.when == "eve" }?.date == NotificationFixtures.date(20, 21, 0))
    // İmsak 05:25, 45 dk önce.
    #expect(plan.first { $0.when == "suhoor" }?.date == NotificationFixtures.date(21, 4, 40))
    #expect(plan.first { $0.when == "eve" }?.body == t("nafile.notifThursday"))
  }

  @Test func suhoorIsOptIn() {
    var p = NotificationFixtures.enabled
    p.fasting = true
    let fast = [FastingDay(date: cal.startOfDay(for: NotificationFixtures.date(21)), kind: .monday)]
    let plan = NotificationPlan.build(days: NotificationFixtures.days, preferences: p, now: NotificationFixtures.date(19, 10), calendar: cal, fasting: fast)
      .filter { $0.kind == .fasting }
    #expect(plan.map(\.when) == ["eve"])
  }

  @Test func nothingWhenOff() {
    let fast = [FastingDay(date: cal.startOfDay(for: NotificationFixtures.date(21)), kind: .monday)]
    let plan = NotificationPlan.build(days: NotificationFixtures.days, preferences: NotificationFixtures.enabled, now: NotificationFixtures.date(19, 10), calendar: cal, fasting: fast)
    #expect(!plan.contains { $0.kind == .fasting })
  }

  @Test func pastEveningIsSkipped() {
    var p = NotificationFixtures.enabled
    p.fasting = true
    // Oruç günü bugün (19): önceki akşam geçti.
    let fast = [FastingDay(date: cal.startOfDay(for: NotificationFixtures.date(19)), kind: .monday)]
    let plan = NotificationPlan.build(days: NotificationFixtures.days, preferences: p, now: NotificationFixtures.date(19, 10), calendar: cal, fasting: fast)
    #expect(!plan.contains { $0.kind == .fasting })
  }

  @Test func preferencesRoundTrip() {
    let entries = ["NAFILE_FAST_REMINDER_ENABLED": "true", "NAFILE_FAST_GROUPS": #"["weekly","arafah","bogus"]"#, "NAFILE_FAST_SUHOOR_ENABLED": "true"]
    let p = NotificationPreferences.read(get: { entries[$0] })
    #expect(p.fasting && p.fastingSuhoor && p.fastingGroups == [.weekly, .arafah])
    let defaults = NotificationPreferences.read(get: { _ in nil })
    #expect(!defaults.fasting && !defaults.fastingSuhoor && defaults.fastingGroups == Set(FastingGroup.allCases))
  }
}

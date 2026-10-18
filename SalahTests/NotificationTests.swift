import Foundation
import Testing
import UserNotifications
@testable import Salah

@MainActor
enum NotificationFixtures {
  static var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return cal
  }
  static func date(_ day: Int = 19, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
  }
  static let times = PrayerTimes(imsak: "05:25", gunes: "06:49", ogle: "12:55", ikindi: "16:13", aksam: "18:51", yatsi: "20:10")
  static var days: [PrayerDay] { (19...22).map { .init(date: "2026-10-\($0)T00:00:00.000Z", times: times) } }
  static var enabled: NotificationPreferences {
    var p = NotificationPreferences()
    p.enabled = true
    return p
  }
  static let verses = (0..<12).map { NotificationInspiration(id: "v\($0)", contentType: "ayet", subtitle: "source", body: String(repeating: "v\($0) ", count: 30), arabic: "عربي") }
  static let hadiths = (0..<12).map { NotificationInspiration(id: "h\($0)", contentType: "hadis", subtitle: "source", body: "hadith \($0)") }
}

@MainActor
struct NotificationPreferencesTests {
  @Test func defaultsMatchRN() {
    let p = NotificationPreferences.read(get: { _ in nil })
    #expect(!p.enabled && p.offsets == [0])
    #expect(p.prayerEnabled["gunes"] == false && p.adhanEnabled["imsak"] == true)
    #expect(p.inspiration && p.religiousDays && p.friday)
  }

  @Test func restoresPartialRNDictionariesAndEpochMilliseconds() {
    let now = NotificationFixtures.date()
    let entries = ["PRAYER_NOTIFICATIONS_ENABLED": "true", "PRAYER_NOTIFICATION_EACH": #"{"ogle":false}"#,
      "ADHAN_PRAYERS_V2": #"{"imsak":false}"#, "NOTIFICATION_MUTE_UNTIL": String(now.addingTimeInterval(3600).timeIntervalSince1970 * 1000)]
    let p = NotificationPreferences.read(now: now, get: { entries[$0] })
    #expect(p.enabled && p.prayerEnabled["ogle"] == false && p.prayerEnabled["yatsi"] == true)
    #expect(p.adhanEnabled["imsak"] == false && p.adhanEnabled["ogle"] == true)
    #expect(p.muteUntil == now.addingTimeInterval(3600))
  }

  @Test(arguments: [("15", [0, 15]), ("0", [0]), ("broken", [0])])
  func legacyOffset(value: String, expected: [Int]) {
    #expect(NotificationPreferences.decodeOffsets(nil, legacy: value) == expected)
  }

  @Test func offsetsRejectCorruptValuesAndKeepValidNumbers() {
    #expect(NotificationPreferences.decodeOffsets(#"[15,"bad",0,15,-3,true,999999999999]"#, legacy: nil) == [0, 15])
    #expect(NotificationPreferences.decodeOffsets("[]", legacy: "15") == [0])
    #expect(NotificationPreferences.decodeOffsets("broken", legacy: "15") == [0, 15])
  }

  @Test(arguments: ["NaN", "Infinity", "0", "-1", "broken"])
  func invalidMuteExpires(raw: String) {
    #expect(NotificationPreferences.read(now: NotificationFixtures.date(), get: { $0 == "NOTIFICATION_MUTE_UNTIL" ? raw : nil }).muteUntil == nil)
  }
}

@MainActor
struct NotificationPlanTests {
  typealias F = NotificationFixtures
  func build(_ p: NotificationPreferences = F.enabled, now: Date = F.date(), verses: [NotificationInspiration] = F.verses, hadiths: [NotificationInspiration] = F.hadiths) -> [PlannedNotification] {
    NotificationPlan.build(days: F.days, preferences: p, now: now, calendar: F.calendar, verses: verses, hadiths: hadiths)
  }

  @Test func threeDaysFivePrayersAndNoSunrise() {
    let prayer = build().filter { $0.kind == .prayerTime }
    #expect(prayer.count == 15)
    #expect(!prayer.contains { $0.prayerKey == "gunes" })
    #expect(prayer.allSatisfy { $0.adhan })
    #expect(Set(prayer.map(\.id)).count == prayer.count)
    #expect(prayer.allSatisfy { F.calendar.component(.day, from: $0.date) <= 21 })
  }

  @Test func masterOffCancelsEveryKind() {
    #expect(build(NotificationPreferences()).isEmpty)
  }

  @Test func legacyMultipleOffsetsCannotConsumeOtherBudgets() {
    var p = F.enabled
    p.offsets = [0, 5, 10, 15, 30]
    p.prayerEnabled["gunes"] = true
    p.adhanEnabled["gunes"] = true
    let plan = build(p)
    #expect(plan.filter { $0.kind == .prayerTime || $0.kind == .prayerReminder }.count == 44)
    #expect(plan.count <= 62)
    #expect(!plan.filter { $0.prayerKey == "gunes" }.contains { $0.adhan })
    #expect(plan.contains { $0.kind == .inspiration })
  }

  @Test func reminderUsesSelectedOffsetWithoutAdhan() {
    var p = F.enabled
    p.offsets = [15]
    let first = build(p).first!
    #expect(first.kind == .prayerReminder && !first.adhan)
    #expect(first.date == F.date(19, 5, 10))
  }

  @Test func neverSchedulesPastTimes() {
    let now = F.date(19, 20, 11)
    #expect(build(now: now).allSatisfy { $0.date > now })
  }

  @Test func muteSchedulesOnlyAfterEndEvenWithoutReopening() {
    var p = F.enabled
    p.muteUntil = F.date(19, 13)
    let plan = build(p)
    #expect(!plan.isEmpty)
    #expect(plan.allSatisfy { $0.date > p.muteUntil! })
    #expect(plan.contains { $0.prayerKey == "ikindi" && $0.date == F.date(19, 16, 13) })
  }

  @Test func blackoutAndDistinctAlternatingContent() {
    let plan = build(now: F.date(19, 22, 37)).filter { $0.kind == .inspiration }
    #expect(plan.count <= 24 && !plan.isEmpty)
    #expect(plan.allSatisfy { (7..<23).contains(F.calendar.component(.hour, from: $0.date)) })
    #expect(plan.allSatisfy { F.calendar.component(.minute, from: $0.date) == 0 })
    #expect(plan.prefix(4).map(\.contentType) == ["ayet", "hadis", "ayet", "hadis"])
    #expect(Set(plan.map(\.body)).count == plan.count)
  }

  @Test func shortVerseFallsBackToHadithAndEmptyPoolsSkip() {
    let short = NotificationInspiration(id: "short", contentType: "ayet", subtitle: "", body: "abc")
    let fallback = build(verses: [short]).filter { $0.kind == .inspiration }
    #expect(fallback.allSatisfy { $0.contentType == "hadis" })
    #expect(!build(verses: [], hadiths: []).contains { $0.kind == .inspiration })
  }

  @Test func fridayTimesMatchRN() {
    let friday = build(now: F.date(22, 12)).filter { $0.kind == .friday }
    #expect(friday.map(\.date) == [F.date(22, 20), F.date(23, 9)])
  }

  @Test func religiousDayReservesSlots() {
    let day = ReligiousDay(id: "example", name: "day", date: F.date(21), hijriDate: "date")
    let plan = NotificationPlan.build(days: F.days, preferences: F.enabled, now: F.date(), calendar: F.calendar,
      verses: F.verses, hadiths: F.hadiths, religiousDays: [day])
    let religious = plan.filter { $0.kind == .religiousDay }
    #expect(religious.map(\.date) == [F.date(20, 20), F.date(21, 8)])
    #expect(plan.count <= 62)
  }

  @Test func alarmCoverageSkipsOnlyExactTime() {
    var p = F.enabled
    p.offsets = [0, 15]
    let plan = NotificationPlan.build(days: F.days, preferences: p, now: F.date(), calendar: F.calendar, alarmCovered: ["imsak"])
    #expect(!plan.contains { $0.prayerKey == "imsak" && $0.offset == 0 })
    #expect(plan.contains { $0.prayerKey == "imsak" && $0.offset == 15 })
  }

  @Test func daylightSavingUsesLocalPrayerClock() {
    var cal = F.calendar
    cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
    let days = [PrayerDay(date: "2026-10-25", times: F.times)]
    let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 25))!
    let first = NotificationPlan.build(days: days, preferences: F.enabled, now: now, calendar: cal).first!
    #expect(cal.component(.hour, from: first.date) == 5)
    #expect(cal.component(.minute, from: first.date) == 25)
  }

  @Test func throttleAndMissingPending() {
    let now = F.date(), last = now.timeIntervalSince1970 * 1000
    #expect(!NotificationPlan.shouldRefresh(last: last, now: now.addingTimeInterval(3600), force: false, hasPending: true))
    #expect(NotificationPlan.shouldRefresh(last: last, now: now.addingTimeInterval(48 * 3600), force: false, hasPending: true))
    #expect(NotificationPlan.shouldRefresh(last: last, now: now, force: true, hasPending: true))
    #expect(NotificationPlan.shouldRefresh(last: last, now: now, force: false, hasPending: false))
  }

  @Test func payloadRetainsLongBodyAndArabic() {
    let body = String(repeating: "long text ", count: 40)
    let content = SystemNotificationDelivery.content(.init(id: "test", date: F.date(), kind: .inspiration,
      title: "title", subtitle: "source", body: body, arabic: "عربي"))
    #expect(content.body != body)
    #expect(content.categoryIdentifier == "spiritual_reminder")
    let payload = NotificationPayload(content.userInfo)
    #expect(payload.inspiration?.text == body && payload.inspiration?.arabic == "عربي")
  }
}

@MainActor
struct ReligiousCalendarTests {
  /// RN utils/__tests__/hijri.test.ts ile aynı girdiler.
  @Test func knownJulianDayAndRoundTrips() {
    let cal = NotificationFixtures.calendar
    #expect(HijriMath.julian(date: cal.date(from: DateComponents(year: 2000, month: 1, day: 1))!, calendar: cal) == 2451545)
    for jdn in stride(from: 2460000, to: 2462000, by: 37) {
      #expect(HijriMath.julian(date: HijriMath.date(jdn, calendar: cal), calendar: cal) == jdn)
    }
    for year in 1440...1460 {
      for month in 1...12 {
        for day in [1, 29] { #expect(HijriMath.hijri(HijriMath.julian(year, month, day)) == .init(year: year, month: month, day: day)) }
      }
    }
  }

  @Test func calibratesAgainstDiyanetAndBuildsRegaib() {
    let cal = NotificationFixtures.calendar
    let date = cal.date(from: DateComponents(year: 2026, month: 2, day: 19))!
    #expect(abs(HijriMath.julian(1447, 9, 1) - HijriMath.julian(date: date, calendar: cal)) <= 1)
    let calendar = ReligiousCalendar(cache: .init(year: 2026, fetchedAt: 0, days: ["2026-02-19": [1447, 9, 1]]), calendar: cal)
    #expect(calendar.date(year: 1447, month: 9, day: 1) == date)
    #expect(calendar.hijri(date) == .init(year: 1447, month: 9, day: 1))
    #expect(calendar.religiousDays(now: date).filter { $0.id.hasPrefix("regaib_") }.allSatisfy { cal.component(.weekday, from: $0.date) == 5 })
  }
}

@MainActor
struct AdhanTimingTests {
  @Test func dedupesForNinetySecondsAndNeverPlaysSunriseOrMuted() {
    let now = NotificationFixtures.date()
    var p = NotificationFixtures.enabled
    #expect(!AdhanTiming.allowed(key: "ogle", preferences: p, now: now, lastKey: "ogle", lastDate: now.addingTimeInterval(-89)))
    #expect(AdhanTiming.allowed(key: "ogle", preferences: p, now: now, lastKey: "ogle", lastDate: now.addingTimeInterval(-90)))
    p.adhanEnabled["gunes"] = true
    #expect(!AdhanTiming.allowed(key: "gunes", preferences: p, now: now, lastKey: nil, lastDate: nil))
    p.muteUntil = now.addingTimeInterval(60)
    #expect(!AdhanTiming.allowed(key: "ogle", preferences: p, now: now, lastKey: nil, lastDate: nil))
  }

  @Test func nextUsesActualTomorrowTimes() {
    let next = AdhanTiming.next(days: NotificationFixtures.days, now: NotificationFixtures.date(19, 23), calendar: NotificationFixtures.calendar)
    #expect(next?.key == "imsak" && next?.date == NotificationFixtures.date(20, 5, 25))
  }
}

@MainActor
final class FakeNotificationDelivery: NotificationDelivery {
  var status = NotificationPermission.allowed
  var notices: [PlannedNotification] = []
  var grants = true
  var failAdd = false
  var failAlternating = false
  var attempts = 0
  var afterAdd: (() -> Void)?
  func permission() async -> NotificationPermission { status }
  func requestPermission() async throws -> Bool { grants }
  func pending() async -> [PendingNotice] { notices.map { .init(id: $0.id, type: $0.kind.rawValue) } }
  func removePending() { notices.removeAll() }
  func add(_ notice: PlannedNotification) async throws {
    attempts += 1
    if failAdd || (failAlternating && attempts % 2 == 0) { throw URLError(.unknown) }
    notices.append(notice)
    afterAdd?()
  }
}

@MainActor
struct NotificationStoreTests {
  typealias F = NotificationFixtures
  func store(_ delivery: FakeNotificationDelivery, days: @escaping () async -> [PrayerDay] = { F.days }) -> NotificationStore {
    NotificationStore(preferences: F.enabled, delivery: delivery, now: { F.date() }, loadDays: days,
      loadPools: { ([], []) }, loadCalendar: { ReligiousCalendar() }, persists: false)
  }

  @Test func permissionDeniedDoesNotLoadOrSchedule() async {
    let d = FakeNotificationDelivery()
    d.status = .denied
    var loads = 0
    let s = store(d, days: { loads += 1; return F.days })
    await s.reschedule(force: true)
    #expect(loads == 0 && d.notices.isEmpty)
    d.grants = false
    #expect(await s.setEnabled(true) == false)
  }

  @Test func disableDuringDeliveryCannotReinstallStalePlan() async {
    let d = FakeNotificationDelivery()
    let actual = store(d)
    var disabled = false
    d.afterAdd = {
      if !disabled { disabled = true; actual.update { $0.enabled = false } }
    }
    await actual.reschedule(force: true)
    #expect(d.notices.isEmpty)
    #expect(!actual.preferences.enabled)
  }

  @Test func missingDaysPreservesPreviousPlan() async {
    let d = FakeNotificationDelivery()
    d.notices = [.init(id: "existing", date: F.date(20), kind: .prayerTime)]
    let s = store(d, days: { [] })
    await s.reschedule(force: true)
    #expect(d.notices.map(\.id) == ["existing"])
  }

  @Test func testNotificationIsAddedAfterReschedule() async {
    let d = FakeNotificationDelivery(), s = store(d)
    #expect(await s.sendTest())
    #expect(d.notices.last?.id.hasPrefix("test.") == true)
    #expect(d.notices.last?.date == F.date().addingTimeInterval(2))
  }

  @Test func failedAddsAreRetriedWithoutThrottle() async {
    let d = FakeNotificationDelivery(), s = store(d)
    d.failAdd = true
    await s.reschedule(force: true)
    #expect(s.lastError != nil)
    d.failAdd = false
    await s.reschedule()
    #expect(!d.notices.isEmpty && s.lastError == nil)
  }

  @Test func partialFailureInvalidatesPreviousSuccessTimestamp() async {
    let d = FakeNotificationDelivery(), s = store(d)
    await s.reschedule(force: true)
    d.failAlternating = true
    await s.reschedule(force: true)
    let before = d.attempts
    #expect(!d.notices.isEmpty && s.lastError != nil)
    d.failAlternating = false
    await s.reschedule()
    #expect(d.attempts > before && s.lastError == nil)
  }

  @Test func testHostNeverSendsBackendRequests() async {
    #expect(DebugLaunch.isIsolated)
    do {
      _ = try await APIClient.shared.send("GET", "/health")
      Issue.record("Test host must block network before creating a request")
    } catch APIError.network(let error) {
      #expect(error.code == .notConnectedToInternet)
    } catch { Issue.record("Unexpected error: \(error)") }
  }
}

@MainActor
struct NotificationNavigationTests {
  @Test func coldStartDeduplicatesAndKeepsFullText() {
    var saved: String?
    var navigations = 0
    let nav = NotificationNavigation(readLast: { saved }, writeLast: { saved = $0 }, openHome: { navigations += 1 })
    let body = String(repeating: "full text ", count: 40)
    let payload = NotificationPayload(["type": "spiritual_reminder", "body": body, "contentType": "hadis", "subtitle": "source"])
    #expect(nav.receive(payload, id: "one"))
    #expect(!nav.receive(payload, id: "one"))
    #expect(nav.inspiration?.text == body && nav.inspiration?.kind == .hadith)
    #expect(navigations == 1 && nav.homeRequest == 1)
    let relaunched = NotificationNavigation(readLast: { saved }, writeLast: { saved = $0 }, openHome: {})
    #expect(!relaunched.receive(payload, id: "one"))
    #expect(nav.receive(payload, id: "two"))
    nav.clear()
    #expect(nav.inspiration == nil)
  }

  @Test func malformedNotificationIsNotMarkedHandled() {
    var written = false
    let nav = NotificationNavigation(readLast: { nil }, writeLast: { _ in written = true }, openHome: {})
    #expect(!nav.receive(NotificationPayload(["type": "spiritual_reminder"]), id: "empty"))
    #expect(!written && nav.inspiration == nil)
  }
}

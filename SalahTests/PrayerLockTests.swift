import DeviceActivity
import Foundation
import Testing
@testable import Salah

/// Vakit kilidi aralığı: vakit girince / vaktin çıkmasına kala, elle girilen dakika ve kısa aralık.
@MainActor
struct PrayerLockTests {
  /// 1 Ekim 2026, yerel saat.
  func at(_ hhmm: String) -> Date {
    let p = hhmm.split(separator: ":").compactMap { Int($0) }
    return Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: p[0], minute: p[1]))!
  }

  func settings(_ change: (inout PrayerLockShared.Settings) -> Void) -> PrayerLockShared.Settings {
    var s = PrayerLockShared.Settings()
    change(&s)
    return s
  }

  @Test func startModeLocksForMinutes() {
    let s = settings { $0.minutes = 58 }
    let w = PrayerLockShared.window(s, start: at("12:55"), end: at("16:13"))
    #expect(w?.from == at("12:55"))
    #expect(w?.to == at("13:53"))
  }

  @Test func startModeNeverPassesTheNextPrayer() {
    let s = settings { $0.minutes = 300 }
    #expect(PrayerLockShared.window(s, start: at("12:55"), end: at("16:13"))?.to == at("16:13"))
  }

  @Test func untilEndLocksTheWholeTime() {
    let s = settings { $0.untilEnd = true }
    let w = PrayerLockShared.window(s, start: at("12:55"), end: at("16:13"))
    #expect(w?.from == at("12:55"))
    #expect(w?.to == at("16:13"))
  }

  @Test func endModeLocksBeforeTheNextPrayer() {
    let s = settings {
      $0.mode = .end
      $0.beforeMinutes = 45
    }
    let w = PrayerLockShared.window(s, start: at("12:55"), end: at("16:13"))
    #expect(w?.from == at("15:28"))
    #expect(w?.to == at("16:13"))
  }

  @Test func endModeNeverStartsBeforeThePrayer() {
    let s = settings {
      $0.mode = .end
      $0.beforeMinutes = 300
    }
    #expect(PrayerLockShared.window(s, start: at("12:55"), end: at("16:13"))?.from == at("12:55"))
  }

  /// Eski kayıtta (yalnız enabled/minutes/prayers) yeni alanlar varsayılanını alır.
  @Test func oldSettingsDecode() throws {
    let json = #"{"enabled":true,"minutes":45,"prayers":["dhuhr"]}"#
    let s = try JSONDecoder().decode(PrayerLockShared.Settings.self, from: Data(json.utf8))
    #expect(s.enabled && s.minutes == 45 && s.prayers == ["dhuhr"])
    #expect(s.mode == .start && !s.untilEnd && s.beforeMinutes == 30)
  }

  /// 15 dakikadan kısa kilit: aralık 15 dakikaya uzar, uyarı asıl bitişte gelir.
  @Test func shortLockUsesWarning() {
    let schedule = PrayerLockStore.schedule(from: at("16:08"), to: at("16:13"))
    #expect(schedule.intervalEnd.hour == 16 && schedule.intervalEnd.minute == 23)
    #expect(schedule.warningTime?.minute == 10 && schedule.warningTime?.second == 0)
  }

  @Test func longLockHasNoWarning() {
    let schedule = PrayerLockStore.schedule(from: at("15:28"), to: at("16:13"))
    #expect(schedule.intervalEnd.hour == 16 && schedule.intervalEnd.minute == 13)
    #expect(schedule.warningTime == nil)
  }
}

import DeviceActivity
import FamilyControls
import Foundation
import Observation

/// Vakit kilidi (uygulama tarafı): izin, seçilen uygulamalar, ayarlar ve vakitlere göre izleme planı.
/// Plan önümüzdeki üç günün vakitleri için kurulur (sistem sınırı 20 etkinlik); her öne gelişte yenilenir.
@MainActor
@Observable
final class PrayerLockStore {
  static let shared = PrayerLockStore()
  /// DeviceActivity aralığı en az 15 dakika olmalı.
  static let minuteOptions = [15, 30, 45, 60]
  static let prayerIds = ["fajr", "dhuhr", "asr", "maghrib", "isha"]

  private(set) var settings = PrayerLockShared.settings()
  private(set) var selection = PrayerLockShared.selection()
  private(set) var authorized = AuthorizationCenter.shared.authorizationStatus == .approved

  var hasSelection: Bool { PrayerLockShared.hasSelection(selection) }

  func requestAuthorization() async -> Bool {
    do {
      try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    } catch {
      authorized = false
      return false
    }
    authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    return authorized
  }

  func setEnabled(_ on: Bool) async {
    if on, !authorized, !(await requestAuthorization()) { return }
    settings.enabled = on
    PrayerLockShared.save(settings)
    if !on { PrayerLockShared.unlock() }
    reschedule()
  }

  func setMinutes(_ value: Int) {
    settings.minutes = value
    PrayerLockShared.save(settings)
    reschedule()
  }

  func toggle(prayer: String) {
    if settings.prayers.contains(prayer) { settings.prayers.removeAll { $0 == prayer } } else { settings.prayers.append(prayer) }
    PrayerLockShared.save(settings)
    reschedule()
  }

  func setSelection(_ value: FamilyActivitySelection) {
    selection = value
    PrayerLockShared.save(value)
    // Kilit sürerken liste değiştiyse yeni seçim hemen uygulanır.
    if let current = PrayerLockShared.currentPrayer { PrayerLockShared.lock(prayer: current) }
    reschedule()
  }

  /// Namaz işaretlenince: o vaktin kilidi kalkar.
  func prayerMarked(_ prayerId: String) {
    if PrayerLockShared.currentPrayer == prayerId { PrayerLockShared.unlock() }
  }

  /// Öne gelişte: kılınmış vaktin kilidi kalkar (widget ya da başka cihazdan işaretlenmiş olabilir), plan yenilenir.
  func foreground() {
    authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    if let current = PrayerLockShared.currentPrayer, PrayerLockShared.isPrayed(current, day: islamicDateString()) { PrayerLockShared.unlock() }
    reschedule()
  }

  /// Plan: her gün seçili vakitlerde [vakit, vakit + süre]. Şu an bir vaktin içindeysek ve kılınmadıysa hemen kilitlenir.
  func reschedule(now: Date = Date()) {
    let center = DeviceActivityCenter()
    center.stopMonitoring(center.activities.filter { $0.rawValue.hasPrefix(PrayerLockShared.activityPrefix) })
    guard settings.enabled, authorized, hasSelection else { return }
    let cal = Calendar.current
    let days = PrayerTimesService.cachedDays(districtId: Locations.selectedDistrictId).prefix(3)
    for day in days {
      guard let date = day.localDay else { continue }
      let dayKey = localDateString(date)
      for prayer in Self.prayerIds where settings.prayers.contains(prayer) {
        guard let key = PrayerSlotState.keys[prayer]?.start, let hhmm = day.times[key] else { continue }
        let start = timeOn(hhmm, date)
        let end = start.addingTimeInterval(TimeInterval(settings.minutes * 60))
        guard end > now else { continue }
        var from = start
        if start <= now {
          // Vaktin içindeyiz: kılınmadıysa hemen kilitle; bitişi izlemek için aralık şimdiden başlar (en az 15 dk).
          guard !PrayerLockShared.isPrayed(prayer, day: dayKey) else { continue }
          PrayerLockShared.lock(prayer: prayer)
          from = now
        }
        let to = max(end, from.addingTimeInterval(15 * 60))
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
          intervalStart: cal.dateComponents(parts, from: from), intervalEnd: cal.dateComponents(parts, from: to), repeats: false
        )
        try? center.startMonitoring(DeviceActivityName(PrayerLockShared.activityName(prayer: prayer, day: dayKey)), during: schedule)
      }
    }
  }
}

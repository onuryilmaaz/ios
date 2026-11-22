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
  static let minuteOptions = [15, 30, 45, 60]
  /// DeviceActivity aralığı en az 15 dakika olmalı; daha kısa kilit, bitişteki uyarıyla (warningTime) açılır.
  private static let minInterval: TimeInterval = 15 * 60
  static let prayerIds = ["fajr", "dhuhr", "asr", "maghrib", "isha"]

  private(set) var settings = PrayerLockShared.settings()
  private(set) var selection = PrayerLockShared.selection()
  private(set) var authorized = AuthorizationCenter.shared.authorizationStatus == .approved
  /// Şu an kilitli vakit (ana sayfa kartı). Uzantı arka planda değiştirir; öne gelişte ve her planlamada okunur.
  private(set) var current = PrayerLockShared.currentPrayer

  var hasSelection: Bool { previewAppCount != nil || PrayerLockShared.hasSelection(selection) }

  /// Mağaza çekimi: izin ve uygulama seçimi varmış gibi (yalnız bellek; sistem kilidi kurulmaz).
  private(set) var previewAppCount: Int?

  #if DEBUG
  func preview() {
    settings.enabled = true
    authorized = true
    previewAppCount = 4
  }
  #endif

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

  /// Ayar ekranının sıralı anlatımı: izin verildi, uygulama seçildi.
  var isReady: Bool { settings.enabled && authorized && hasSelection }

  func setMode(_ mode: PrayerLockShared.Settings.Mode) {
    update { $0.mode = mode }
  }

  /// `start` kipinde kilit süresi.
  func setMinutes(_ value: Int) {
    update {
      $0.minutes = Self.clamp(value)
      $0.untilEnd = false
    }
  }

  /// `start` kipinde vakit çıkana kadar.
  func setUntilEnd() {
    update { $0.untilEnd = true }
  }

  /// `end` kipinde vaktin çıkmasına kaç dakika kala.
  func setBeforeMinutes(_ value: Int) {
    update { $0.beforeMinutes = Self.clamp(value) }
  }

  private static func clamp(_ value: Int) -> Int {
    min(PrayerLockShared.minuteRange.upperBound, max(PrayerLockShared.minuteRange.lowerBound, value))
  }

  private func update(_ change: (inout PrayerLockShared.Settings) -> Void) {
    var next = settings
    change(&next)
    guard next != settings else { return }
    settings = next
    PrayerLockShared.save(next)
    // Ayar değişince süren kilit yeni aralığa göre yeniden kurulur.
    PrayerLockShared.unlock()
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
    current = PrayerLockShared.currentPrayer
  }

  /// Öne gelişte: kılınmış vaktin kilidi kalkar (widget ya da başka cihazdan işaretlenmiş olabilir), plan yenilenir.
  func foreground() {
    authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    if let current = PrayerLockShared.currentPrayer, PrayerLockShared.isPrayed(current, day: islamicDateString()) { PrayerLockShared.unlock() }
    reschedule()
  }

  /// Plan: her gün seçili vakitlerde ayara göre kilit aralığı (bkz. `PrayerLockShared.window`).
  /// Şu an bir aralığın içindeysek ve vakit kılınmadıysa hemen kilitlenir.
  func reschedule(now: Date = Date()) {
    defer { current = PrayerLockShared.currentPrayer }
    let center = DeviceActivityCenter()
    center.stopMonitoring(center.activities.filter { $0.rawValue.hasPrefix(PrayerLockShared.activityPrefix) })
    guard settings.enabled, authorized, hasSelection else { return }
    // Yatsının çıkışı ertesi günün imsakı: bir gün fazlası okunur.
    let days = Array(PrayerTimesService.cachedDays(districtId: Locations.selectedDistrictId).prefix(4))
    for (index, day) in days.prefix(3).enumerated() {
      guard let date = day.localDay else { continue }
      let dayKey = localDateString(date)
      for prayer in Self.prayerIds where settings.prayers.contains(prayer) {
        guard let keys = PrayerSlotState.keys[prayer], let hhmm = day.times[keys.start] else { continue }
        let start = timeOn(hhmm, date)
        let end: Date
        if let endKey = keys.end, let value = day.times[endKey] {
          end = timeOn(value, date)
        } else if index + 1 < days.count, let next = days[index + 1].localDay {
          end = timeOn(days[index + 1].times.imsak, next)
        } else {
          end = timeOn(day.times.imsak, date, dayOffset: 1)
        }
        guard let window = PrayerLockShared.window(settings, start: start, end: end), window.to > now else { continue }
        var from = window.from
        if from <= now {
          // Aralığın içindeyiz: kılınmadıysa hemen kilitle; bitişi izlemek için aralık şimdiden başlar.
          guard !PrayerLockShared.isPrayed(prayer, day: dayKey) else { continue }
          PrayerLockShared.lock(prayer: prayer)
          from = now
        }
        try? center.startMonitoring(
          DeviceActivityName(PrayerLockShared.activityName(prayer: prayer, day: dayKey)), during: Self.schedule(from: from, to: window.to)
        )
      }
    }
  }

  /// 15 dakikadan kısa kilitte aralık 15 dakikaya uzatılır; asıl bitiş `warningTime` ile bildirilir
  /// (izleme uzantısı `intervalWillEndWarning`'de açar).
  static func schedule(from: Date, to: Date) -> DeviceActivitySchedule {
    let cal = Calendar.current
    let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    let short = to.timeIntervalSince(from) < minInterval
    let intervalEnd = short ? from.addingTimeInterval(minInterval) : to
    var warning: DateComponents?
    if short {
      let seconds = Int(intervalEnd.timeIntervalSince(to).rounded())
      warning = DateComponents(minute: seconds / 60, second: seconds % 60)
    }
    return DeviceActivitySchedule(
      intervalStart: cal.dateComponents(parts, from: from), intervalEnd: cal.dateComponents(parts, from: intervalEnd),
      repeats: false, warningTime: warning
    )
  }
}

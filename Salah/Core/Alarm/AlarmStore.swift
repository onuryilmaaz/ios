import Foundation
import UIKit

/// Alarm durumu ve senkron. RN: modules/alarm/alarm.store.ts + alarm.service.ts
/// (aynı anahtarlar: `ALARM_SETTINGS_V1`, `ALARM_LAST_SYNC_AT`).
@Observable
final class AlarmStore {
  static let shared = AlarmStore()

  enum Auth: String { case authorized, denied, notDetermined, unsupported }

  private(set) var settings: AlarmSettings
  /// AlarmKit var mı (iOS 26+). Ekran, kart ve hızlı menü buna göre görünür.
  private(set) var supported = AlarmKitBridge.isSupported
  private(set) var auth: Auth = .unsupported
  /// Sıradaki kurulu alarm.
  private(set) var next: (fireAt: Date, title: String)?
  /// Sistem sınırına takıldıysa uzak günler kurulamamıştır.
  private(set) var limitReached = false

  private static let settingsKey = "ALARM_SETTINGS_V1"
  private static let lastSyncKey = "ALARM_LAST_SYNC_AT"
  /// Plan 14 günlük; her açılışta değil, en çok 6 saatte bir yenilenir.
  private static let throttle: TimeInterval = 6 * 3600

  /// Uygulama vakit anahtarı → widget vakit kimliği ("Kıldım" için).
  static let widgetPrayerID = ["imsak": "sabah", "ogle": "ogle", "ikindi": "ikindi", "aksam": "aksam", "yatsi": "yatsi"]

  @ObservationIgnored private var chain: Task<Void, Never>?

  private init() {
    settings = LocalStore.decode(AlarmSettings.self, Self.settingsKey) ?? .defaults
    auth = AlarmKitBridge.authorization
  }

  var authorized: Bool { supported && auth == .authorized }

  /// Tam vaktinde alarm çalan vakitler: o vakitlerin "vakit girdi" bildirimi atlanır.
  var coveredPrayerKeys: Set<String> {
    guard authorized else { return [] }
    return Set(settings.prayers.filter { $0.value.enabled && $0.value.offset == 0 }.map(\.key))
  }

  /// Alarmları ayarlara ve önümüzdeki günlerin vakitlerine göre yeniden kurar.
  /// force=false iken 6 saatte birden sık kurmaz. Senkronlar sıraya girer.
  func sync(force: Bool = false) async {
    let previous = chain
    let task = Task {
      await previous?.value
      await run(force: force)
    }
    chain = task
    await task.value
  }

  func update(_ change: (inout AlarmSettings) -> Void) async {
    change(&settings)
    LocalStore.encode(settings, for: Self.settingsKey)
    await sync(force: true)
  }

  @discardableResult
  func requestAuthorization() async -> Auth {
    auth = await AlarmKitBridge.requestAuthorization()
    if auth == .authorized { await sync(force: true) }
    return auth
  }

  /// Açmadan önce izin: ilk kez sorulur, reddedildiyse Ayarlar'a yönlendirilir.
  func ensureAuthorized() async -> Bool {
    if auth == .authorized { return true }
    if auth == .denied {
      showDenied()
      return false
    }
    let status = await requestAuthorization()
    if status == .authorized {
      Haptics.notify(.success)
      return true
    }
    if status == .denied { showDenied() }
    return false
  }

  /// Vakit alarmını günceller; bildirim planı da yenilenebilir (tam vakit bildirimi atlansın).
  @discardableResult
  func setPrayer(_ key: String, enabled: Bool? = nil, offset: Int? = nil, rescheduleNotifications: Bool = true) async -> Bool {
    if enabled == true, !(await ensureAuthorized()) { return false }
    await update { s in
      var p = s.prayers[key] ?? .init(enabled: false, offset: 0)
      if let enabled { p.enabled = enabled }
      if let offset { p.offset = offset }
      s.prayers[key] = p
    }
    if rescheduleNotifications { Task { await NotificationStore.shared.reschedule(force: true) } }
    return true
  }

  private func showDenied() {
    AppAlert.show(.warning, t("alarm.permission.title"), t("alarm.permission.denied"), buttons: [
      .init(text: t("common.cancel"), style: .cancel),
      .init(text: t("alarm.permission.openSettings")) {
        if let url = URL(string: UIApplication.openSettingsURLString) { await UIApplication.shared.open(url) }
      },
    ])
  }

  // MARK: - Senkron

  private func run(force: Bool) async {
    #if DEBUG
    if previewing { return }
    #endif
    supported = AlarmKitBridge.isSupported
    guard supported, !DebugLaunch.isIsolated else {
      auth = supported ? AlarmKitBridge.authorization : .unsupported
      return
    }
    auth = AlarmKitBridge.authorization

    if !force, let last = LocalStore.string(Self.lastSyncKey).flatMap(Double.init),
      Date().timeIntervalSince1970 * 1000 - last < Self.throttle * 1000
    {
      // Kurulu alarmlara dokunma ama "sıradaki alarm"ı göster.
      if authorized, AlarmPlan.hasAnyAlarm(settings) { next = Self.nextOf(await plan()) }
      return
    }

    guard AlarmPlan.hasAnyAlarm(settings), auth == .authorized else {
      // Hepsi kapandıysa ya da izin geri alındıysa bekleyenleri temizle.
      _ = await AlarmKitBridge.sync([])
      next = nil
      limitReached = false
      markSynced()
      return
    }

    let planned = await plan()
    let result = await AlarmKitBridge.sync(planned.map(spec))
    next = Self.nextOf(planned)
    limitReached = result.limitReached
    markSynced()
  }

  private func markSynced() {
    LocalStore.set(String(Date().timeIntervalSince1970 * 1000), for: Self.lastSyncKey)
  }

  private func plan() async -> [AlarmPlan.Planned] {
    let districtId = LocalStore.string(Locations.districtIdKey)
    let days = districtId == nil ? [] : await PrayerTimesService.upcomingDays(districtId: districtId!)
    let planDays = days.map { d in
      AlarmPlan.Day(
        date: d.date,
        times: ["imsak": d.times.imsak, "gunes": d.times.gunes, "ogle": d.times.ogle, "ikindi": d.times.ikindi, "aksam": d.times.aksam, "yatsi": d.times.yatsi],
        hijriMonth: d.hijri_date?.month)
    }
    return AlarmPlan.build(days: planDays, settings: settings, now: Date())
  }

  private static func nextOf(_ plan: [AlarmPlan.Planned]) -> (fireAt: Date, title: String)? {
    plan.first.map { ($0.fireAt, title($0)) }
  }

  static func title(_ a: AlarmPlan.Planned) -> String {
    switch a {
    case .prayer(_, let key, let offset):
      let prayer = prayerLabel(key)
      if offset == 0 { return t("alarm.title.atTime", ["prayer": prayer]) }
      return offset < 0 ? t("alarm.title.before", ["prayer": prayer, "min": -offset]) : t("alarm.title.after", ["prayer": prayer, "min": offset])
    case .tahajjud: return t("alarm.title.tahajjud")
    case .sahur: return t("alarm.title.sahur")
    case .custom(_, _, let label):
      let trimmed = label.trimmingCharacters(in: .whitespaces)
      return trimmed.isEmpty ? t("alarm.title.custom") : trimmed
    }
  }

  private func spec(_ a: AlarmPlan.Planned) -> AlarmKitBridge.Spec {
    var prayerId = ""
    var kind = "custom"
    var isPrayer = false
    var prayerKey = ""
    var offset = 0
    switch a {
    case .prayer(_, let key, let off):
      isPrayer = true
      kind = "prayer"
      prayerKey = key
      offset = off
      prayerId = Self.widgetPrayerID[key] ?? ""
    case .tahajjud: kind = "tahajjud"
    case .sahur: kind = "sahur"
    case .custom: kind = "custom"
    }
    // "Kıldım" yalnız vakit girdikten sonra çalan alarmda anlamlı.
    let canMark = isPrayer && settings.secondary == "mark" && !prayerId.isEmpty && offset >= 0
    let sound: String =
      switch settings.sound {
      case "adhan": isPrayer && prayerKey != "gunes" ? "alarm_\(prayerKey).caf" : ""
      case "default": ""
      default: AlarmPlan.toneSounds[settings.sound] ?? ""
      }
    return AlarmKitBridge.Spec(
      fireDate: a.fireAt, title: Self.title(a), kind: kind, prayerId: prayerId, sound: sound,
      secondary: canMark ? "mark" : "snooze", secondaryLabel: t(canMark ? "alarm.button.mark" : "alarm.button.snooze"),
      snoozeSeconds: Double(settings.snoozeMinutes * 60), snoozeTitle: t("alarm.snoozed"), stopLabel: t("alarm.button.stop"))
  }

  #if DEBUG
  @ObservationIgnored private var previewing = false

  /// Mağaza görseli fikstürü: örnek alarm ayarları ve sıradaki alarm; sisteme alarm kurmaz.
  func preview(_ settings: AlarmSettings, next: (fireAt: Date, title: String)?) {
    previewing = true
    self.settings = settings
    self.next = next
    supported = true
    auth = .authorized
  }
  #endif
}

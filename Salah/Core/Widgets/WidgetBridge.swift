import ActivityKit
import Foundation
import WidgetKit

/// Widget'lar ve Live Activity için App Group verisi. Anahtarlar ve JSON biçimi RN köprüsüyle
/// (widget-src/SalahLiveActivityModule.swift) birebir aynı; widget kaynakları değişmeden okur.
enum WidgetBridge {
  static let appGroupID = "group.com.onur6541.salah.shared"

  private static var defaults: UserDefaults? { DebugLaunch.isIsolated ? nil : UserDefaults(suiteName: appGroupID) }

  private static func write(_ dict: Any, key: String, reload kind: String?) {
    guard let ud = defaults, let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
    if ud.data(forKey: key) == data { return }
    ud.set(data, forKey: key)
    if let kind { WidgetCenter.shared.reloadTimelines(ofKind: kind) } else { WidgetCenter.shared.reloadAllTimelines() }
  }

  /// Widget ve Live Activity metinlerinin dili (WidgetL10n.swift okur).
  static func setLanguage(_ lang: String) {
    guard let ud = defaults, ud.string(forKey: "appLanguage") != lang else { return }
    ud.set(lang, forKey: "appLanguage")
    WidgetCenter.shared.reloadAllTimelines()
  }

  /// Premium widget'ların erişim hakkı. Premium kapalıyken herkes erişir (kilit yok).
  static func setPremiumAccess(_ active: Bool) {
    guard let ud = defaults, ud.object(forKey: "salah_is_premium") as? Bool != active else { return }
    ud.set(active, forKey: "salah_is_premium")
    WidgetCenter.shared.reloadAllTimelines()
  }

  /// Widget'ın kendi başına (Kıldım düğmesi) istek atabilmesi için sunucu adresi; token'lar ortak Keychain'de.
  static func setAPIURL(_ url: String) {
    guard let ud = defaults, ud.string(forKey: "salah_api_url") != url else { return }
    ud.set(url, forKey: "salah_api_url")
  }

  static func updatePrayerTimes(_ times: PrayerTimes, window: PrayerWindow) {
    write(
      [
        "prayerName": window.prayerName, "prayerTime": formatHHMM(window.end), "nextPrayer": window.nextPrayer,
        "endTimeMs": window.end.timeIntervalSince1970 * 1000,
        "imsak": times.imsak, "gunes": times.gunes, "ogle": times.ogle, "ikindi": times.ikindi, "aksam": times.aksam, "yatsi": times.yatsi,
      ], key: "salah_widget_data", reload: "SalahPrayerTimesWidget")
  }

  /// Yeni namaz gününe geçilince önceki gün `_prev`'te saklanır: widget'lar gece yarısından
  /// İmsak'a kadar dünün kayıtlarını (ör. kılınan yatsı) okur.
  static func updateTracker(completed: [String], kaza: [String], date: String) {
    guard let ud = defaults else { return }
    if let existing = ud.data(forKey: "salah_tracker_data"),
      let obj = try? JSONSerialization.jsonObject(with: existing) as? [String: Any],
      let existingDate = obj["date"] as? String, existingDate != date
    {
      ud.set(existing, forKey: "salah_tracker_data_prev")
    }
    write(["completedPrayers": completed, "kazaPrayers": kaza, "date": date], key: "salah_tracker_data", reload: nil)
  }

  static func updateAmel(types: [String], total: Int, date: String) {
    write(["types": types, "totalCount": total, "date": date], key: "salah_amel_data", reload: "SalahAmelWidget")
  }

  static func updateInspiration(text: String, source: String, type: String, arabic: String, date: String) {
    write(["text": text, "source": source, "type": type, "arabic": arabic, "date": date], key: "salah_inspiration_data", reload: "SalahInspirationWidget")
  }

  /// Kilit ekranı için önümüzdeki günlerin ayetleri; widget gece yarısı kendisi geçer.
  static func updateVerses(_ items: [[String: String]]) {
    write(items, key: "salah_inspiration_verses", reload: "SalahInspirationWidget")
  }

  /// Widget'lar sıradaki alarmı gösterebilsin diye kurulu alarm saatleri (en yakın 40).
  static func publishAlarmDates(_ dates: [Date]) {
    guard let ud = defaults else { return }
    ud.set(dates.prefix(40).map(\.timeIntervalSince1970), forKey: "salah_alarm_dates")
    WidgetCenter.shared.reloadAllTimelines()
  }

  /// Widget'ın "Kıldım" ile işaretleyip sunucuya gönderemediği vakitler ("fajr" ya da "fajr:kaza").
  static func takePendingPrayers() -> [(id: String, kaza: Bool)] {
    guard let ud = defaults, let raw = ud.string(forKey: "salah_pending_prayers"), !raw.isEmpty else { return [] }
    ud.removeObject(forKey: "salah_pending_prayers")
    return raw.split(separator: ",").compactMap { entry in
      let parts = entry.split(separator: ":")
      guard let id = parts.first, ["fajr", "dhuhr", "asr", "maghrib", "isha"].contains(String(id)) else { return nil }
      return (String(id), parts.count > 1 && parts[1] == "kaza")
    }
  }
}

/// Dynamic Island / kilit ekranı vakit kartı. RN: PrayerTimesCard `syncPrayerActivity` +
/// SalahLiveActivityModule. Aynı pencere için yeniden başlatılmaz; sunucu push ile
/// sonraki geçişleri günceller, push yoksa vakit bitince kart kalkar.
@MainActor
enum PrayerLiveActivity {
  private static var lastKey = ""

  static func sync(times: PrayerTimes, completed: [String], now: Date = Date()) {
    guard !DebugLaunch.isIsolated, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let w = PrayerWindow.compute(times, completed: completed, now: now)
    let key = "\(w.mode.rawValue)|\(w.prayerName)|\(Int(w.end.timeIntervalSince1970))"
    guard key != lastKey else { return }
    lastKey = key
    let timeline = PrayerWindow.timeline(times, completed: completed, now: now)
    Task { await start(w, timeline: timeline) }
  }

  private static func state(_ w: PrayerWindow) -> SitePongActivityAttributes.ContentState {
    .init(prayerName: w.prayerName, nextPrayer: w.nextPrayer, endTimeMs: w.end.timeIntervalSince1970 * 1000,
          mode: w.mode.rawValue, startTimeMs: (w.start?.timeIntervalSince1970 ?? 0) * 1000)
  }

  private static func start(_ w: PrayerWindow, timeline: [(at: Date, window: PrayerWindow)]) async {
    for activity in Activity<SitePongActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    // staleDate = vakit bitişi: sistem bu ana kadar sayacı işletir.
    let content = ActivityContent(state: state(w), staleDate: w.end)
    let activity: Activity<SitePongActivityAttributes>
    do {
      // Push token'lı: sunucu vakit geçişlerinde kartı APNs ile günceller (uygulama kapalıyken de).
      activity = try Activity.request(attributes: SitePongActivityAttributes(), content: content, pushType: .token)
    } catch {
      guard let fallback = try? Activity.request(attributes: SitePongActivityAttributes(), content: content, pushType: nil) else { return }
      activity = fallback
    }
    var pushing = false
    if let token = await firstPushToken(activity) { pushing = await schedulePushes(token, timeline: timeline) }
    if !pushing { await armAutoEnd(id: activity.id) }
  }

  /// İlk push token'ı (hex); 4 sn içinde gelmezse nil.
  private static func firstPushToken(_ activity: Activity<SitePongActivityAttributes>) async -> String? {
    final class Once {
      var continuation: CheckedContinuation<String?, Never>?
      func finish(_ value: String?) {
        continuation?.resume(returning: value)
        continuation = nil
      }
    }
    let once = Once()
    return await withCheckedContinuation { continuation in
      once.continuation = continuation
      let reader = Task {
        for await data in activity.pushTokenUpdates {
          once.finish(data.map { String(format: "%02x", $0) }.joined())
          return
        }
        once.finish(nil)
      }
      Task {
        try? await Task.sleep(for: .seconds(4))
        reader.cancel()
        once.finish(nil)
      }
    }
  }

  /// Sunucu push gönderebiliyorsa true (uç yok / APNs ayarsız / hata: false).
  private static func schedulePushes(_ token: String, timeline: [(at: Date, window: PrayerWindow)]) async -> Bool {
    struct Response: Decodable { let pushEnabled: Bool? }
    let updates = timeline.map { item -> JSONValue in
      let s = state(item.window)
      return .object([
        "atMs": .number(item.at.timeIntervalSince1970 * 1000),
        "state": .object([
          "prayerName": .string(s.prayerName), "nextPrayer": .string(s.nextPrayer), "endTimeMs": .number(s.endTimeMs),
          "mode": .string(s.mode), "startTimeMs": .number(s.startTimeMs),
        ]),
      ])
    }
    let res = try? await APIClient.shared.post("/live-activity/schedule", body: ["pushToken": .string(token), "updates": .array(updates)], as: Response.self)
    return res?.pushEnabled == true
  }

  /// Push yoksa vakit bitince (1 dk sonra) kart kilit ekranından kalkar.
  private static func armAutoEnd(id: String) async {
    guard let activity = Activity<SitePongActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
    let c = activity.content.state
    guard c.endTimeMs > 0 else { return }
    let dismissAt = Date(timeIntervalSince1970: c.endTimeMs / 1000).addingTimeInterval(60)
    // Durum kopyalanır (aktiviteyle aynı bölgede kalmasın).
    let s = SitePongActivityAttributes.ContentState(
      prayerName: c.prayerName, nextPrayer: c.nextPrayer, endTimeMs: c.endTimeMs, mode: c.mode, startTimeMs: c.startTimeMs)
    for fresh in Activity<SitePongActivityAttributes>.activities where fresh.id == id {
      await fresh.end(ActivityContent(state: s, staleDate: nil), dismissalPolicy: .after(dismissAt))
    }
  }
}

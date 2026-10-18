import Foundation

/// Widget verisini uygulamanın durumundan güncel tutar. RN'de bu iş PrayerTimesCard,
/// PrayerTrackerCard, HomeScreen, language.store ve App.tsx'e dağılmıştı.
@MainActor
enum WidgetSync {
  private static var times: PrayerTimes?
  private static var windowTimer: Task<Void, Never>?

  /// Açılışta ve öne gelişte: dil, sunucu adresi, premium erişimi, bekleyen "Kıldım"lar, ayetler.
  static func activate() async {
    WidgetBridge.setLanguage(Localizer.shared.language.rawValue)
    WidgetBridge.setAPIURL(APIClient.shared.baseURL.absoluteString)
    // Premium kapalı: widget'lar herkese açık (RN: setPremiumStatus(!PREMIUM_ENABLED || isPremium)).
    WidgetBridge.setPremiumAccess(true)
    await processPendingPrayers()
    await syncVerses()
  }

  static func languageChanged() async {
    WidgetBridge.setLanguage(Localizer.shared.language.rawValue)
    await syncVerses()
  }

  /// Vakit widget'ı ve Live Activity. Kılınan namaz ya da vakit geçişi pencereyi değiştirir;
  /// pencere bitince kendiliğinden yeniden hesaplanır.
  static func updatePrayer(_ times: PrayerTimes?) {
    if let times { self.times = times }
    guard let times = self.times else { return }
    let completed = GamificationStore.shared.stats?.today_prayers ?? []
    let now = Date()
    let w = PrayerWindow.compute(times, completed: completed, now: now)
    WidgetBridge.updatePrayerTimes(times, window: w)
    PrayerLiveActivity.sync(times: times, completed: completed, now: now)

    windowTimer?.cancel()
    windowTimer = Task {
      try? await Task.sleep(for: .seconds(max(1, w.end.timeIntervalSince(now) + 1)))
      guard !Task.isCancelled else { return }
      updatePrayer(nil)
    }
  }

  /// Widget'ın sunucuya gönderemeyip sıraya koyduğu vakitler normal takip akışıyla işlenir.
  private static func processPendingPrayers() async {
    // Oturum yüklenmeden App Group kuyruğunu tüketme.
    guard AuthStore.shared.isAuthenticated, !DebugLaunch.isIsolated else { return }
    let pending = WidgetBridge.takePendingPrayers()
    for p in pending {
      do {
        _ = try await GamificationStore.shared.trackPrayer(p.id, isKaza: p.kaza)
      } catch {
        // Ağ hatası trackPrayer içinde zaten kuyruğa alınır. Buraya kalan
        // geçici sunucu/oturum hataları da widget işaretini kaybettirmesin.
        if (error as? APIError)?.status != 400 {
          OfflineQueue.shared.enqueue(method: "post", url: "/prayer/track",
            body: ["prayer_time": .string(p.id), "is_kaza": .bool(p.kaza), "date": .string(islamicDateString())])
        }
      }
    }
  }

  // MARK: - Kilit ekranı ayetleri (RN: modules/liveActivity/widgetVerses.ts)

  private struct StoredVerses: Codable {
    var lang: String
    var items: [Verse]
    struct Verse: Codable { var date, text, source, arabic: String }
  }

  private static let versesKey = "@salah_widget_verses_v1"
  private static let daysAhead = 7
  /// Elde bu kadar günden az kaldıysa liste tamamlanır.
  private static let refillBelow = 4
  /// Kilit ekranı dikdörtgeni ~4 satır; çok uzun mealler kesiliyor.
  private static let maxText = 170
  private static var versesTask: Task<Void, Never>?

  /// Widget gece yarısı kendi zaman çizelgesinden o günün ayetine geçer; böylece gün
  /// dönümünde uygulama açılmadan da içerik değişir.
  static func syncVerses(force: Bool = false) async {
    if let versesTask { return await versesTask.value }
    let task = Task { await runVerses(force: force) }
    versesTask = task
    await task.value
    versesTask = nil
  }

  private static func runVerses(force: Bool) async {
    guard !DebugLaunch.isIsolated else { return }
    let lang = Localizer.shared.language.rawValue
    let today = localDateString()
    let stored = LocalStore.decode(StoredVerses.self, versesKey)
    var items = !force && stored?.lang == lang ? (stored?.items ?? []).filter { $0.date >= today } : []
    let before = items.count

    if items.count < refillBelow {
      let have = Set(items.map(\.date))
      for i in 0..<daysAhead {
        let date = localDateString(Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date())
        if have.contains(date) { continue }
        guard let v = await pickVerse(date) else { break }  // ağ yok: eldekiyle devam
        items.append(v)
      }
      items.sort { $0.date < $1.date }
    }

    guard !items.isEmpty else { return }
    // Değişmediyse de yaz: widget eklendikten sonra veri hiç gelmemiş olabilir.
    WidgetBridge.updateVerses(items.map { ["date": $0.date, "text": $0.text, "source": $0.source, "arabic": $0.arabic] })
    if items.count != before || stored?.lang != lang || force {
      LocalStore.encode(StoredVerses(lang: lang, items: items), for: versesKey)
    }
  }

  private static func pickVerse(_ date: String) async -> StoredVerses.Verse? {
    var fallback: StoredVerses.Verse?
    for _ in 0..<3 {
      guard let r = await QuranService.randomVerse(), !r.verse.translation.text.isEmpty else { continue }
      let item = StoredVerses.Verse(
        date: date,
        text: r.verse.translation.text.trimmingCharacters(in: .whitespacesAndNewlines),
        source: t("notif.verseRef", ["surah": surahName(r.surah, withSuffix: true), "verse": r.verse.verse_number]),
        arabic: r.verse.verse_simplified)
      if item.text.count <= maxText { return item }
      if fallback == nil || item.text.count < fallback!.text.count { fallback = item }
    }
    return fallback
  }
}

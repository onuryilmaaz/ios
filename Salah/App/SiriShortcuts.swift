import AppIntents
import Foundation

/// Siri ve Kısayollar: "Sıradaki vakit" ve "Kıldım". Uygulama sürecinde çalışır (arka planda açılabilir),
/// bu yüzden ana sayfanın kullandığı store'ları ve kuralları (`PrayerWindow`, `PrayerSlotState`,
/// `GamificationStore.trackPrayer`, çevrimdışı kuyruk) doğrudan kullanır.
/// Başlıklar `Localizable.strings`, Siri cümleleri `AppShortcuts.strings` (sistem bunları uygulamayı
/// açmadan okur); konuşulan yanıtlar uygulamanın seçili dilinden (`t`).
struct SalahShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: NextPrayerIntent(),
      phrases: [
        "Next prayer in \(.applicationName)",
        "When is the next prayer in \(.applicationName)",
      ],
      shortTitle: "shortcut.nextPrayer",
      systemImageName: "clock"
    )
    AppShortcut(
      intent: MarkCurrentPrayerIntent(),
      phrases: [
        "Mark my prayer in \(.applicationName)",
        "I prayed in \(.applicationName)",
      ],
      shortTitle: "shortcut.markPrayer",
      systemImageName: "checkmark.circle"
    )
  }

  static var shortcutTileColor: ShortcutTileColor { .grayGreen }
}

struct NextPrayerIntent: AppIntent {
  static let title: LocalizedStringResource = "intent.nextPrayer.title"
  static let description = IntentDescription("intent.nextPrayer.description")
  static let openAppWhenRun = false

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    UsageStore.shared.record("siri.next")
    let text = await SiriPrayer.nextPrayerText(now: Date())
    return .result(value: text, dialog: IntentDialog(stringLiteral: text))
  }
}

struct MarkCurrentPrayerIntent: AppIntent {
  static let title: LocalizedStringResource = "intent.markPrayer.title"
  static let description = IntentDescription("intent.markPrayer.description")
  static let openAppWhenRun = false

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    UsageStore.shared.record("siri.mark")
    let text = await SiriPrayer.markCurrent(now: Date())
    return .result(dialog: IntentDialog(stringLiteral: text))
  }
}

@MainActor
enum SiriPrayer {
  /// Uygulama yalnız intent için açıldıysa (sahne yok) oturum henüz okunmamıştır.
  static func prepare() async {
    if !AuthStore.shared.hydrated { await AuthStore.shared.hydrate() }
    GamificationStore.shared.ensureFreshToday()
  }

  static func todayTimes() async -> PrayerTimes? {
    let district = Locations.selectedDistrictId
    let today = Calendar.current.startOfDay(for: Date())
    if let cached = PrayerTimesService.cachedDays(districtId: district).first(where: { $0.localDay == today }) {
      return cached.times
    }
    return await PrayerTimesService.today(districtId: district)?.times
  }

  static func nextPrayerText(now: Date) async -> String {
    guard let times = await todayTimes() else { return t("siri.noTimes") }
    // Kılınanlardan bağımsız: soru vaktin kendisi.
    let w = PrayerWindow.compute(times, completed: [], now: now)
    let vars: [String: any CustomStringConvertible] = [
      "prayer": prayerLabel(w.prayerName), "time": formatHHMM(w.end), "remaining": remaining(from: now, to: w.end),
    ]
    return t(w.mode == .current ? "siri.next.current" : "siri.next.upcoming", vars)
  }

  static func markCurrent(now: Date) async -> String {
    await prepare()
    guard AuthStore.shared.isAuthenticated else { return t("siri.signIn") }
    guard !OzelGunStore.shared.isActive else { return t("siri.ozelGun") }
    guard let times = await todayTimes() else { return t("siri.noTimes") }

    let w = PrayerWindow.compute(times, completed: [], now: now)
    guard w.mode == .current, let id = PrayerSlotState.idsByName[w.prayerName],
      PrayerSlotState.of(id, times: times, now: now) == .current
    else {
      // Güneş–Öğle arası ya da 04:00–imsak (yeni namaz günü, Sabah girmedi).
      let next = w.mode == .current ? w.nextPrayer : w.prayerName
      return t("siri.mark.none", ["prayer": prayerLabel(next), "time": formatHHMM(w.end)])
    }

    let store = GamificationStore.shared
    let label = prayerLabel(id)
    if store.stats?.today_prayers.contains(id) == true { return t("siri.mark.already", ["prayer": label]) }
    do {
      guard let result = try await store.trackPrayer(id, isKaza: false) else {
        return store.stats?.today_prayers.contains(id) == true
          ? t("siri.mark.already", ["prayer": label]) : t("siri.mark.failed")
      }
      if result.offline { return t("siri.mark.offline", ["prayer": label]) }
      return t("siri.mark.done", ["prayer": label, "count": store.stats?.today_prayers.count ?? result.todayCount])
    } catch {
      if (error as? APIError)?.status == 400 { return t("siri.mark.already", ["prayer": label]) }
      return t("siri.mark.failed")
    }
  }

  /// "1 saat 5 dakika" (seçili dilde, çoğul kurallarıyla).
  static func remaining(from now: Date, to end: Date) -> String {
    let f = DateComponentsFormatter()
    f.allowedUnits = end.timeIntervalSince(now) >= 3600 ? [.hour, .minute] : [.minute]
    f.unitsStyle = .full
    var cal = Calendar.current
    cal.locale = Localizer.shared.locale
    f.calendar = cal
    // Dakikanın kesri yukarı yuvarlanır: 30 sn kalmışsa "1 dakika".
    let seconds = max(60, (end.timeIntervalSince(now) / 60).rounded(.up) * 60)
    return f.string(from: seconds) ?? ""
  }
}

import Foundation

#if DEBUG
/// Mağaza görselleri için örnek oturum (`-SalahDebugSample YES`, izole): örnek kullanıcı, bugünkü namazlar,
/// seri, ibadet kayıtları, 12 aylık istatistik ve alarm ayarları. Yalnız bellekte; sunucuya ve sisteme
/// yazmaz. Android DebugLaunch `salah.debug.signedIn` + `tracker sample` + `alarms sample` karşılığı.
enum StorePreview {
  static func install() {
    // Kilit ekranı kartı ve widget'lar seçili dilde (normalde WidgetSync.activate yazar; izole modda çalışmaz).
    WidgetBridge.setLanguage(Localizer.shared.language.rawValue)
    AuthStore.shared.preview(AuthUser(id: "preview-user", email: "ornek@email.com", firstName: "Ayşe", lastName: "Yılmaz"))

    let cal = Calendar.current
    let today = Date()
    func day(_ offset: Int) -> String { localDateString(cal.date(byAdding: .day, value: offset, to: today) ?? today) }

    var stats = GamificationStore.Stats()
    stats.today_prayers = ["fajr", "dhuhr"]
    stats.kaza_prayers = ["fajr"]
    stats.current_streak = 12
    stats.highest_streak = 30
    let daily: [JSONValue] = (1...6).reversed().map { i in
      .object(["date": .string(day(-i)), "prayer_count": .number(Double([5, 5, 3, 5, 5, 0][6 - i]))])
    }
    GamificationStore.shared.preview(stats: stats, weekly: .object(["daily": .array(daily)]))

    let note: String
    switch Localizer.shared.language {
    case .en: note = "Al-Baqarah 15-18"
    case .ar: note = "البقرة ١٥-١٨"
    default: note = "Bakara 15-18"
    }
    let todayKey = day(0)
    TrackerStore.shared.preview([
      TrackerLog(id: "p1", date: todayKey, activity_type: "quran", value: .object(["pages": .number(4), "minutes": .number(20)]), notes: note, created_at: nil),
      TrackerLog(id: "p2", date: todayKey, activity_type: "nafile", value: .object(["type": .string("teheccud"), "rakaat": .number(2)]), notes: nil, created_at: nil),
      TrackerLog(id: "p3", date: todayKey, activity_type: "sadaka", value: .object(["amount": .number(100)]), notes: nil, created_at: nil),
    ])

    let pattern = [5, 5, 3, 5, 0, 4, 5, 2, 5, 5, 1]
    let ozel = Set((40..<46).map { day(-$0) })
    let days: [InsightsStore.HistoryDay] = (0..<371).reversed().map { i in
      let d = cal.date(byAdding: .day, value: -i, to: today) ?? today
      let key = localDateString(d)
      let count = ozel.contains(key) ? 0 : pattern[(i * 7 + cal.component(.day, from: d)) % pattern.count]
      return InsightsStore.HistoryDay(date: key, count: count, kaza: nil)
    }
    let weekday = (cal.component(.weekday, from: today) + 5) % 7 + 1  // Pazartesi = 1
    let weekStart = cal.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
    let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
    func recap(_ period: String, _ from: Date, _ n: Int) -> InsightsStore.Recap {
      InsightsStore.Recap(
        period: period, from: localDateString(from), to: todayKey, days: n, prayers: n * 4, possiblePrayers: n * 5,
        kaza: 2, perfectDays: n / 2,
        byPrayerTime: ["fajr": n - 2, "dhuhr": n, "asr": n - 1, "maghrib": n, "isha": n - 1],
        quranPages: n * 3, activities: ["quran": n, "nafile": 3, "sadaka": 1], currentStreak: 12, highestStreak: 30)
    }
    InsightsStore.shared.preview(
      history: .init(from: days.first?.date ?? todayKey, to: todayKey, days: days, ozelGun: Array(ozel)),
      recaps: [
        "week": recap("week", weekStart, max(3, weekday)),
        "month": recap("month", monthStart, max(5, cal.component(.day, from: today))),
      ],
      quran: .init(totalPages: 1210, completedHatims: 1, currentPages: 206, pagesPerHatim: 604))

    var alarms = AlarmSettings.defaults
    alarms.prayers["imsak"] = .init(enabled: true, offset: 15)
    alarms.prayers["ogle"] = .init(enabled: true, offset: 0)
    alarms.tahajjud.enabled = true
    alarms.custom = [
      .init(id: "preview", hour: 9, minute: 30, days: [1, 2, 3, 4, 5], onceAt: nil, label: t("alarm.custom.labelPlaceholder"), enabled: true),
      .init(id: "preview2", hour: 22, minute: 0, days: [], onceAt: nil, label: "", enabled: true),
    ]
    var next = cal.date(byAdding: .day, value: 1, to: today) ?? today
    next = cal.date(bySettingHour: 5, minute: 56, second: 0, of: next) ?? next
    AlarmStore.shared.preview(alarms, next: (next, t("alarm.title.after", ["prayer": prayerLabel("imsak"), "min": 15])))
  }
}
#endif

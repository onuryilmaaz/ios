import Foundation

@Observable
final class NotificationStore {
  static let shared = NotificationStore()
  /// V3: ezan sesi varsayılanı kapandı; güncellemeden sonraki ilk açılış eski (ezan sesi
  /// gömülü) planı throttle'a takılmadan yeniden kursun. RN'in V2 damgası da devralınmaz.
  static let lastScheduleKey = "NOTIF_LAST_RESCHEDULE_AT_V3"

  private(set) var preferences: NotificationPreferences
  private(set) var permission = NotificationPermission.unknown
  private(set) var isScheduling = false
  private(set) var lastError: String?
  private(set) var revision = 0
  @ObservationIgnored private let delivery: any NotificationDelivery
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let loadDays: () async -> [PrayerDay]
  @ObservationIgnored private let loadPools: () async -> (verses: [NotificationInspiration], hadiths: [NotificationInspiration])
  @ObservationIgnored private let loadCalendar: () async -> ReligiousCalendar
  @ObservationIgnored private let persists: Bool
  @ObservationIgnored private var worker: Task<Void, Never>?
  @ObservationIgnored private var forceNext = false
  @ObservationIgnored private var lastScheduled: Double?

  init(
    preferences: NotificationPreferences? = nil,
    delivery: any NotificationDelivery = SystemNotificationDelivery(),
    now: @escaping () -> Date = { Date() },
    loadDays: @escaping () async -> [PrayerDay] = {
      guard let district = LocalStore.string(Locations.districtIdKey) else { return [] }
      return await PrayerTimesService.upcomingDays(districtId: district)
    },
    loadPools: @escaping () async -> (verses: [NotificationInspiration], hadiths: [NotificationInspiration]) = { await NotificationContentPool.load() },
    loadCalendar: @escaping () async -> ReligiousCalendar = { await ReligiousCalendarService.load() },
    persists: Bool = true
  ) {
    self.preferences = preferences ?? NotificationPreferences.read()
    self.delivery = delivery
    self.now = now
    self.loadDays = loadDays
    self.loadPools = loadPools
    self.loadCalendar = loadCalendar
    self.persists = persists
    if persists {
      lastScheduled = LocalStore.string(Self.lastScheduleKey).flatMap(Double.init)
      if LocalStore.string("PRAYER_NOTIFICATION_OFFSETS") == nil, LocalStore.string("PRAYER_NOTIFICATION_OFFSET") != nil {
        LocalStore.encode(self.preferences.offsets, for: "PRAYER_NOTIFICATION_OFFSETS")
      }
    }
  }

  func setEnabled(_ enabled: Bool) async -> Bool {
    if enabled {
      do {
        guard try await delivery.requestPermission() else { permission = .denied; return false }
      } catch { lastError = String(describing: error); return false }
      permission = .allowed
    }
    update { $0.enabled = enabled }
    // İçerik indirme sürerken ana anahtar kapatılabilsin; update planlamayı başlatır.
    return true
  }

  func update(_ change: (inout NotificationPreferences) -> Void) {
    change(&preferences)
    revision += 1
    forceNext = true
    invalidateSchedule()
    if persists { save() }
    // Bir ağ isteği sürerken kapat/sessize al hemen etkili olsun.
    if !preferences.enabled || preferences.isMuted(at: now()) { delivery.removePending() }
    Task { await reschedule(force: true) }
  }

  func mute(minutes: Int) {
    update { $0.muteUntil = now().addingTimeInterval(Double(max(1, minutes)) * 60) }
  }

  func unmute() { update { $0.muteUntil = nil } }

  func refreshMute() {
    if let date = preferences.muteUntil, date <= now() {
      preferences.muteUntil = nil
      if persists { LocalStore.set(nil, for: "NOTIFICATION_MUTE_UNTIL") }
      // Sessiz aralık sonrası zaten kurulu; throttle boyunca iptal etmeye gerek yok.
    }
  }

  func reschedule(force: Bool = false) async {
    guard !DebugLaunch.isIsolated || !persists else { return }
    // Zorunlu yenileme kalıcı olsun: uygulama kapanır, ağ düşer ya da araya başka
    // bir yenileme girerse eski plan (ör. ezan sesi gömülü bildirimler) throttle'a takılmasın.
    if force { invalidateSchedule() }
    forceNext = forceNext || force
    revision += 1
    if let worker { await worker.value; return }
    let task = Task { await self.run() }
    worker = task
    await task.value
    worker = nil
  }

  private func run() async {
    isScheduling = true
    defer { isScheduling = false }
    while true {
      // forceNext yalnız plan kurulunca düşer; yarıda kalan tur (continue) zorunluluğu kaybetmez.
      let version = revision, force = forceNext
      refreshMute()
      let snapshot = preferences
      permission = await delivery.permission()
      guard version == revision else { continue }
      guard snapshot.enabled, permission == .allowed else {
        delivery.removePending()
        forceNext = false
        return
      }
      let pending = await delivery.pending()
      guard version == revision else { continue }
      guard NotificationPlan.shouldRefresh(last: lastScheduled, now: now(), force: force, hasPending: !pending.isEmpty) else { return }
      let days = await loadDays()
      guard version == revision else { continue }
      // Ağ başarısızsa eldeki bildirimleri koru ve throttle damgası yazma.
      guard !days.isEmpty else { return }
      // Tam vaktinde alarm çalan vakitte ayrıca "vakit girdi" bildirimi gelmesin.
      let alarmCovered = AlarmStore.shared.coveredPrayerKeys
      // 1. aşama: vakit bildirimleri içerik indirmeyi beklemeden hemen kurulur; ezan
      // sesi gibi ayar değişiklikleri saniyeler içinde eski bildirimlerin yerini alır.
      let prayers = NotificationPlan.build(days: days, preferences: snapshot, now: now(), alarmCovered: alarmCovered)
        .filter(\.isPrayer)
      delivery.removePending()
      lastError = nil
      var succeeded = await add(prayers, version: version)
      guard version == revision else { continue }
      // 2. aşama: ayet/hadis, dini gün ve cuma bildirimleri (ağdan içerik gerekir).
      let pools = snapshot.inspiration ? await loadPools() : (verses: [], hadiths: [])
      guard version == revision else { continue }
      let calendar = snapshot.religiousDays ? await loadCalendar() : ReligiousCalendar()
      guard version == revision else { continue }
      let rest = NotificationPlan.build(days: days, preferences: snapshot, now: now(), verses: pools.verses,
                                        hadiths: pools.hadiths, religiousDays: calendar.religiousDays(now: now()),
                                        alarmCovered: alarmCovered)
        .filter { !$0.isPrayer }
      succeeded = await add(rest, version: version) && succeeded
      guard version == revision else { continue }
      forceNext = false
      if succeeded {
        lastScheduled = now().timeIntervalSince1970 * 1000
        if persists { LocalStore.set(String(lastScheduled!), for: Self.lastScheduleKey) }
      } else {
        lastScheduled = nil
        if persists { LocalStore.set(nil, for: Self.lastScheduleKey) }
      }
      return
    }
  }

  /// Planı sırayla kurar; ayar değişirse (revision) yarıda bırakır. Hepsi eklendiyse true.
  private func add(_ notices: [PlannedNotification], version: Int) async -> Bool {
    var succeeded = true
    for notice in notices {
      guard version == revision else { break }
      // İçerik indirilirken vakit geçmiş olabilir.
      guard notice.date > now() else { continue }
      do { try await delivery.add(notice) }
      catch { lastError = String(describing: error); succeeded = false }
    }
    return succeeded
  }

  /// Throttle damgasını siler: sonraki reschedule() (yeniden açılışta da) planı mutlaka yeniden kurar.
  private func invalidateSchedule() {
    lastScheduled = nil
    if persists { LocalStore.set(nil, for: Self.lastScheduleKey) }
  }

  func summary() async -> (total: Int, prayer: Int, other: Int) {
    let all = await delivery.pending()
    let prayer = all.filter { $0.type == "prayer_time" || $0.type == "prayer_reminder" }.count
    return (all.count, prayer, all.count - prayer)
  }

  func sendTest() async -> Bool {
    guard await delivery.permission() == .allowed else { return false }
    // Yenileme TAMAMLANDIKTAN sonra test ekle: cancelAll testi silmesin.
    await reschedule(force: true)
    let pools = await loadPools()
    let item = (pools.verses + pools.hadiths).randomElement()
    let kind = item?.contentType ?? "ayet"
    let notice = PlannedNotification(id: "test.\(UUID().uuidString)", date: now().addingTimeInterval(2), kind: .inspiration,
      title: item == nil ? t("notif.testTitle") : t(kind == "hadis" ? "notif.hadithTitle" : "notif.verseTitle"),
      subtitle: item?.subtitle ?? t("notif.testSubtitle"), body: item?.body ?? t("notif.testBody"),
      arabic: item?.arabic ?? "", contentType: kind)
    do { try await delivery.add(notice); return true }
    catch { lastError = String(describing: error); return false }
  }

  private func save() {
    let p = preferences
    LocalStore.set(String(p.enabled), for: "PRAYER_NOTIFICATIONS_ENABLED")
    LocalStore.encode(p.offsets, for: "PRAYER_NOTIFICATION_OFFSETS")
    LocalStore.encode(p.prayerEnabled, for: "PRAYER_NOTIFICATION_EACH")
    LocalStore.encode(p.adhanEnabled, for: "ADHAN_PRAYERS_V2")
    LocalStore.set(String(p.inspiration), for: "REMINDER_ENABLED")
    LocalStore.set(String(p.religiousDays), for: "RELIGIOUS_DAY_NOTIFICATIONS_ENABLED")
    LocalStore.set(String(p.friday), for: "CUMA_REMINDER_ENABLED")
    LocalStore.set(p.muteUntil.map { String($0.timeIntervalSince1970 * 1000) }, for: "NOTIFICATION_MUTE_UNTIL")
  }

  #if DEBUG
  func preview(_ section: String) {
    preferences.enabled = true
    if section == "mute" { preferences.muteUntil = Date().addingTimeInterval(3600) }
  }
  #endif
}

enum NotificationContentPool {
  /// RN: en fazla 5 × 5 ayet denemesi, hadislerde 2 × hedef; benzersiz havuz.
  static func load() async -> (verses: [NotificationInspiration], hadiths: [NotificationInspiration]) {
    guard !DebugLaunch.isIsolated else { return ([], []) }
    var verses: [NotificationInspiration] = [], hadiths: [NotificationInspiration] = []
    var seen = Set<String>()
    for _ in 0..<5 where verses.count < 12 {
      let batch = (0..<5).map { _ in Task { await QuranService.randomVerse() } }
      for task in batch {
        guard let r = await task.value else { continue }
        let id = "\(r.surah.id):\(r.verse.verse_number)", text = r.verse.translation.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard verses.count < 12, (text as NSString).length >= 60, seen.insert(id).inserted else { continue }
        verses.append(.init(id: id, contentType: "ayet", subtitle: t("notif.verseRef", ["surah": surahName(r.surah), "verse": r.verse.verse_number]), body: text, arabic: r.verse.verse_simplified))
      }
    }
    for _ in 0..<24 where hadiths.count < 12 {
      guard let h = await HadithService.random(), !h.text.isEmpty, seen.insert(h.text).inserted else { continue }
      hadiths.append(.init(id: h.text, contentType: "hadis", subtitle: h.bookName, body: h.text))
    }
    return (verses.shuffled(), hadiths.shuffled())
  }
}

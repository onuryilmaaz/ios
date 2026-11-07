import Foundation
import Observation

/// Ayarlar'daki Ramazan modu: kart, imsakiye girişi, hatim planı ve hatırlatmasının tek anahtarı.
@MainActor
@Observable
final class RamadanMode {
  static let shared = RamadanMode()
  private static let key = "@salah_ramadan_mode_v1"

  /// nil: kullanıcı hiç seçmedi, takvime göre.
  private(set) var stored: Bool? = LocalStore.decode(Bool.self, key)

  private var debugForced: Bool {
    #if DEBUG
    return DebugLaunch.ramadan != nil
    #else
    return false
    #endif
  }

  /// Kullanıcı kapattı: takvimde Ramazan olsa da görünmez.
  var isForcedOff: Bool { stored == false && !debugForced }

  func isOn(now: Date = Date(), calendar: Calendar = .current) -> Bool {
    if debugForced { return true }
    if let stored { return stored }
    let real = RamadanPlan.window(ReligiousCalendarService.cached(), now: now, calendar: calendar)
    return RamadanPlan.isModeOn(stored: nil, real: real, now: now, calendar: calendar)
  }

  func isPreview(now: Date = Date(), calendar: Calendar = .current) -> Bool {
    guard stored == true else { return false }
    let real = RamadanPlan.window(ReligiousCalendarService.cached(), now: now, calendar: calendar)
    return RamadanPlan.usesPreview(stored: stored, real: real, now: now, calendar: calendar)
  }

  func set(_ value: Bool) {
    stored = value
    LocalStore.encode(value, for: Self.key)
    Task { await NotificationStore.shared.reschedule(force: true) }
    WidgetSync.ramadanChanged()
  }
}

/// Oruç defteri ve kaza sayacı. Yerelde hemen yazılır, girişliyse /ramadan/sync ile eşitlenir (bkz. RamadanLedger).
/// Bugünün orucu ayrıca İbadet kaydı olur; geçmiş günlerin işareti yalnız deftere yazılır.
@MainActor
@Observable
final class RamadanStore {
  static let shared = RamadanStore()
  private static let key = "@salah_ramadan_ledger_v1"
  private static let refreshInterval: TimeInterval = 3600

  private(set) var ledger: RamadanLedger = LocalStore.decode(RamadanLedger.self, key) ?? RamadanLedger()
  @ObservationIgnored private var syncing = false
  @ObservationIgnored private var lastSync: Date?

  private struct SyncResponse: Decodable {
    struct Payload: Decodable {
      var days: [String]
      var kaza: Int
    }
    var data: Payload?
  }

  /// Yerel işaretler, artı formdan girilmiş bugünkü kayıt.
  func count(hijriYear: Int) -> Int {
    let today = localDateString()
    let days = ledger.days(hijriYear)
    let extra = !days.contains(today) && hijriYear != RamadanPlan.previewHijriYear && Self.todayLog(today) != nil
    return days.count + (extra ? 1 : 0)
  }

  func isFasted(_ day: String, hijriYear: Int) -> Bool {
    ledger.days(hijriYear).contains(day) || (hijriYear != RamadanPlan.previewHijriYear && Self.todayLog(day) != nil)
  }

  func toggle(_ day: String, hijriYear: Int) async {
    let fasted = !isFasted(day, hijriYear: hijriYear)
    save(ledger.marking(hijriYear, day: day, fasted: fasted))
    if hijriYear != RamadanPlan.previewHijriYear {
      if !fasted {
        if let log = Self.todayLog(day) { try? await TrackerStore.shared.delete(log.id) }
      } else if day == localDateString(), AuthStore.shared.isAuthenticated {
        _ = try? await TrackerStore.shared.log(.fasting, value: .object(["type": .string("ramazan")]), notes: nil)
      }
    }
    await sync(force: true)
  }

  func addKaza(_ delta: Int) async {
    save(ledger.addingKaza(delta))
    await sync(force: true)
  }

  /// Widget düğmesinin bıraktığı işaretler (uygulama açılınca).
  func applyWidgetMarks(_ marks: [String: Bool], hijriYear: Int) async {
    guard !marks.isEmpty else { return }
    var next = ledger
    for (day, fasted) in marks { next = next.marking(hijriYear, day: day, fasted: fasted) }
    save(next)
    await sync(force: true)
  }

  /// Bekleyenleri gönderir ve yılın güncel halini alır; bekleyen yoksa ve yakın zamanda eşitlendiyse ağa çıkmaz.
  func sync(force: Bool = false) async {
    guard !DebugLaunch.isIsolated, AuthStore.shared.isAuthenticated, !syncing else { return }
    let waiting = !ledger.pending.isEmpty || ledger.kazaPending != 0
    if !force, !waiting, let lastSync, Date().timeIntervalSince(lastSync) < Self.refreshInterval { return }
    syncing = true
    defer { syncing = false }
    let current = RamadanPlan.window(ReligiousCalendarService.cached(), now: Date(), calendar: .current).hijriYear
    let years = Set(ledger.pending.keys.compactMap { Int($0) }).union([current])
    do {
      for year in years.sorted() {
        let sent = ledger.pending[String(year)] ?? [:]
        let sentKaza = ledger.kazaPending
        let body: JSONValue = .object([
          "hijri_year": .number(Double(year)),
          "changes": .array(sent.map { .object(["day": .string($0.key), "fasted": .bool($0.value)]) }),
          "kaza_delta": .number(Double(sentKaza)),
        ])
        let res = try await APIClient.shared.post("/ramadan/sync", body: body, as: SyncResponse.self)
        guard let data = res.data else { return }
        save(ledger.merged(year, sent: sent, sentKaza: sentKaza, serverDays: data.days, serverKaza: data.kaza))
      }
      lastSync = Date()
    } catch {
      // Ağ, sunucu ya da henüz yayınlanmamış uç: bekleyenler bir sonraki eşitlemeye kalır.
    }
  }

  /// Oturum kapanınca: defter hesabındır.
  func reset() {
    lastSync = nil
    save(RamadanLedger())
  }

  private func save(_ value: RamadanLedger) {
    ledger = value
    LocalStore.encode(value, for: Self.key)
    WidgetSync.ramadanChanged()
  }

  private static func todayLog(_ day: String) -> TrackerLog? {
    TrackerStore.shared.todayLogs.first { $0.date.hasPrefix(day) && $0.type == .fasting && $0.text("type") == "ramazan" }
  }
}

/// Bu cihazdaki hatim planı (sunucuda plan alanı yok; ilerleme zaten sunucudaki Kur'an kayıtlarından gelir).
@MainActor
@Observable
final class HatimPlanStore {
  static let shared = HatimPlanStore()
  private static let key = "@salah_hatim_plan_v1"

  private(set) var plan: HatimPlan? = {
    #if DEBUG
    if DebugLaunch.ramadan != nil, DebugLaunch.isIsolated {
      let target = Calendar.current.date(byAdding: .day, value: 20, to: Date()) ?? Date()
      return UserDefaults.standard.bool(forKey: "SalahDebugHatim") ? HatimPlan(targetDate: localDateString(target), startHatims: 2, reminderHour: 21, reminderMinute: 0) : nil
    }
    #endif
    return LocalStore.decode(HatimPlan.self, key)
  }()

  func set(_ value: HatimPlan?) {
    plan = value
    if let value { LocalStore.encode(value, for: Self.key) } else { LocalStore.set(nil, for: Self.key) }
    Task { await NotificationStore.shared.reschedule(force: true) }
  }

  /// Sunucudaki hatim ve bugünkü Kur'an kayıtlarıyla ilerleme; veri henüz yoksa nil.
  func progress(now: Date = Date(), calendar: Calendar = .current) -> HatimPlan.Progress? {
    guard let plan, let q = InsightsStore.shared.quran, q.pagesPerHatim > 0 else { return nil }
    return plan.progress(completedHatims: q.completedHatims, currentPages: q.currentPages, pagesPerHatim: q.pagesPerHatim, todayRead: todayRead, today: now, calendar: calendar)
  }

  /// Bugünkü Kur'an kayıtlarındaki sayfa toplamı.
  var todayRead: Int {
    TrackerStore.shared.todayLogs.filter { $0.type == .quran }.reduce(0) { $0 + Int($1.number("pages")) }
  }

  /// Bildirim planına giden hatırlatma: plan sürüyorsa.
  func reminder(now: Date = Date()) -> HatimReminder? {
    guard RamadanMode.shared.isOn(now: now), let plan, let hour = plan.reminderHour, let minute = plan.reminderMinute, let p = progress(now: now), !p.finished, !p.overdue else { return nil }
    return .init(hour: hour, minute: minute, dailyPages: p.dailyTarget, targetDate: plan.targetDate)
  }
}

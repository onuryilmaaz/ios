import Foundation
import Observation

/// Ramazan bölümünün tek karar noktası: panel kapalıysa herkese kapalı. Panel açıkken herkes takvime göre görür,
/// yönetici hesabı Ramazan dışında da örnek pencereyle görür.
@MainActor
final class RamadanMode {
  static let shared = RamadanMode()

  private var debugForced: Bool {
    #if DEBUG
    return DebugLaunch.ramadan != nil
    #else
    return false
    #endif
  }

  var isAdmin: Bool { AuthStore.shared.user?.roles?.contains("admin") == true }

  /// Panelden kapalı: takvimde Ramazan olsa da görünmez.
  var isForcedOff: Bool { !AppControlStore.shared.isOn("ramadan") && !debugForced }

  func isOn(now: Date = Date(), calendar: Calendar = .current) -> Bool {
    if debugForced { return true }
    if !AppControlStore.shared.isOn("ramadan") { return false }
    let real = RamadanPlan.window(ReligiousCalendarService.cached(), now: now, calendar: calendar)
    return RamadanPlan.isModeOn(admin: isAdmin, real: real, now: now, calendar: calendar)
  }

  /// Değişince hatırlatmalar ve widget'lar yenilenir: panel, zamanlama ya da yönetici girişi.
  var scheduleKey: [Bool] { [isOn(), AppControlStore.shared.isOn("hatim_plan")] }
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
      var marks: [String: [String]]?
      var ozel_gun_days: [String]?
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

  /// Teravih, İbadet'teki bugünkü teravih nafile kaydıyla eşleşir (oruçtaki gibi).
  func isMarked(_ kind: String, day: String, hijriYear: Int) -> Bool {
    ledger.markDays(hijriYear, kind: kind).contains(day) || (kind == Self.teravihKind && hijriYear != RamadanPlan.previewHijriYear && Self.teravihLog(day) != nil)
  }

  func markCount(_ kind: String, hijriYear: Int, today: String = localDateString()) -> Int {
    let days = ledger.markDays(hijriYear, kind: kind)
    let extra = !days.contains(today) && kind == Self.teravihKind && hijriYear != RamadanPlan.previewHijriYear && Self.teravihLog(today) != nil
    return days.count + (extra ? 1 : 0)
  }

  /// Bugünün teravihi ayrıca 20 rekat nafile kaydı olur; işaret kalkınca kayıt silinir. Geçmiş günler yalnız deftere yazılır.
  func toggleMark(_ kind: String, day: String, hijriYear: Int) async {
    let on = !isMarked(kind, day: day, hijriYear: hijriYear)
    save(ledger.settingMark(hijriYear, kind: kind, day: day, on: on))
    if kind == Self.teravihKind, hijriYear != RamadanPlan.previewHijriYear {
      if !on {
        if let log = Self.teravihLog(day) { try? await TrackerStore.shared.delete(log.id) }
      } else if day == localDateString(), AuthStore.shared.isAuthenticated {
        _ = try? await TrackerStore.shared.log(.nafile, value: .object(["type": .string("teravih"), "rakaat": .number(20)]), notes: nil)
      }
    }
    await sync(force: true)
  }

  static let teravihKind = "taraweeh"

  private static func teravihLog(_ day: String) -> TrackerLog? {
    TrackerStore.shared.todayLogs.first { $0.date.hasPrefix(day) && $0.type == .nafile && $0.text("type") == "teravih" }
  }

  func applyKaza(hijriYear: Int, days: [String]) async {
    save(ledger.applyingKaza(hijriYear, days: days))
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
    let waiting = !ledger.pending.isEmpty || !ledger.pendingMarks.isEmpty || ledger.kazaPending != 0
    if !force, !waiting, let lastSync, Date().timeIntervalSince(lastSync) < Self.refreshInterval { return }
    syncing = true
    defer { syncing = false }
    let window = RamadanPlan.window(ReligiousCalendarService.cached(), now: Date(), calendar: .current)
    let current = window.hijriYear
    let years = Set(ledger.pending.keys.compactMap { Int($0) }).union(ledger.pendingMarks.keys.compactMap { Int($0) }).union([current])
    do {
      for year in years.sorted() {
        let sent = ledger.pending[String(year)] ?? [:]
        let sentMarks = ledger.pendingMarks[String(year)] ?? [:]
        let sentKaza = ledger.kazaPending
        var fields: [String: JSONValue] = [
          "hijri_year": .number(Double(year)),
          "changes": .array(sent.map { .object(["day": .string($0.key), "fasted": .bool($0.value)]) }),
          "kaza_delta": .number(Double(sentKaza)),
          "marks": .array(sentMarks.compactMap { id, on in
            let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return .object(["kind": .string(parts[0]), "day": .string(parts[1]), "on": .bool(on)])
          }),
        ]
        if year == current {
          fields["window"] = .object(["start": .string(localDateString(window.start)), "end": .string(localDateString(window.last))])
        }
        let body: JSONValue = .object(fields)
        let res = try await APIClient.shared.post("/ramadan/sync", body: body, as: SyncResponse.self)
        guard let data = res.data else { return }
        save(ledger.merged(year, sent: sent, sentKaza: sentKaza, serverDays: data.days, serverKaza: data.kaza, sentMarks: sentMarks, serverMarks: data.marks, serverOzelGun: data.ozel_gun_days))
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

/// Zekât ve fitre ölçüleri: sunucudan gelir, yoksa son bilinen Diyanet değeri.
@MainActor
@Observable
final class RamadanConfigStore {
  static let shared = RamadanConfigStore()
  private static let key = "@salah_ramadan_config_v1"

  struct Config: Codable, Equatable {
    var fitreAmount = 240.0
    var fidyeAmount = 240.0
    var currency = "TRY"
    var period = "2026-2027"
    var nisabGoldGrams = 80.18
    /// Sunucunun saatte bir aldığı gram altın fiyatı; alınamadıysa nil.
    var goldPricePerGram: Double?
    var goldPriceAt: String?
  }
  private struct Response: Decodable { let data: Config? }

  private(set) var config = LocalStore.decode(Config.self, key) ?? Config()

  func refresh() async {
    guard !DebugLaunch.isIsolated, let fresh = try? await APIClient.shared.get("/ramadan/config", as: Response.self).data else { return }
    config = fresh
    LocalStore.encode(fresh, for: Self.key)
  }
}

/// Hatim planı: yerelde hemen yazılır, girişliyse `/ramadan/hatim-plan` ile eşitlenir. Son değiştiren cihaz kazanır.
/// İlerleme zaten sunucudaki Kur'an kayıtlarından gelir.
@MainActor
@Observable
final class HatimPlanStore {
  static let shared = HatimPlanStore()
  private static let key = "@salah_hatim_plan_v1"
  private static let pendingKey = "@salah_hatim_plan_pending_v1"
  private static let syncedKey = "@salah_hatim_plan_synced_v1"
  private struct Response: Decodable { let data: HatimPlan? }
  @ObservationIgnored private var syncing = false

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
    store(value)
    LocalStore.set("true", for: Self.pendingKey)
    Task {
      await NotificationStore.shared.reschedule(force: true)
      await sync()
    }
  }

  private func store(_ value: HatimPlan?) {
    plan = value
    if let value { LocalStore.encode(value, for: Self.key) } else { LocalStore.set(nil, for: Self.key) }
  }

  /// Bekleyen değişiklik varsa gönderir, yoksa sunucudaki planı alır. Eski sürümden kalan yerel plan bir kez gönderilir.
  func sync() async {
    guard !DebugLaunch.isIsolated, AuthStore.shared.isAuthenticated, !syncing else { return }
    syncing = true
    defer { syncing = false }
    let pending = LocalStore.string(Self.pendingKey) == "true" || (plan != nil && LocalStore.string(Self.syncedKey) == nil)
    do {
      if pending {
        let sent = plan
        try await APIClient.shared.send("PUT", "/ramadan/hatim-plan", body: ["plan": Self.body(sent)])
        // Gönderim sürerken plan değiştiyse bekleyen işaret kalır, sonraki eşitlemede gider.
        if plan == sent { LocalStore.set(nil, for: Self.pendingKey) }
      } else {
        let remote = try await APIClient.shared.get("/ramadan/hatim-plan", as: Response.self).data
        if remote != plan {
          store(remote)
          await NotificationStore.shared.reschedule(force: true)
        }
      }
      LocalStore.set("true", for: Self.syncedKey)
    } catch {
      // Çevrimdışı ya da geçici hata: yerel plan kalır, sonraki açılışta yeniden denenir.
    }
  }

  private static func body(_ plan: HatimPlan?) -> JSONValue {
    guard let plan else { return .null }
    return .object([
      "targetDate": .string(plan.targetDate),
      "startHatims": .number(Double(plan.startHatims)),
      "reminderHour": plan.reminderHour.map { .number(Double($0)) } ?? .null,
      "reminderMinute": plan.reminderMinute.map { .number(Double($0)) } ?? .null,
    ])
  }

  /// Oturum kapanınca: plan hesabındır, sonraki girişte sunucudan gelir.
  func reset() {
    store(nil)
    LocalStore.set(nil, for: Self.pendingKey)
    LocalStore.set(nil, for: Self.syncedKey)
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
    guard RamadanMode.shared.isOn(now: now), AppControlStore.shared.isOn("hatim_plan"), let plan, let hour = plan.reminderHour, let minute = plan.reminderMinute, let p = progress(now: now), !p.finished, !p.overdue else { return nil }
    return .init(hour: hour, minute: minute, dailyPages: p.dailyTarget, targetDate: plan.targetDate)
  }
}

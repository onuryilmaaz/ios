import Foundation
import Observation

/// Kaza namazı borcu: kişi başına tek JSON (`GET/PUT /kaza`, `POST /kaza/adjust`). - / + farkla gönderilir, iki cihaz ve
/// çevrimdışı kuyruk birbirini ezmez. Namaz kaydı (takipte "kaza") sayacı etkilemez (kullanıcı kararı).
/// Yalnız girişli kullanıcıda ve sunucu `kaza` özelliğini destekliyorsa açılır.
enum KazaPlan {
  /// Sayaç sırası; vitir yalnız `witr` açıksa gösterilir.
  static let prayers = ["fajr", "dhuhr", "asr", "maghrib", "isha", "witr"]
  static let max = 100_000

  static func visiblePrayers(witr: Bool) -> [String] { witr ? prayers : Array(prayers.dropLast()) }

  static func total(_ counts: [String: Int], witr: Bool) -> Int {
    visiblePrayers(witr: witr).reduce(0) { $0 + (counts[$1] ?? 0) }
  }

  /// Her gün her vakitten `perDay` kaza kılınırsa borcun biteceği gün (en büyük sayaca göre). Borç yoksa nil.
  static func finishDate(_ counts: [String: Int], witr: Bool, perDay: Int, from: Date, calendar: Calendar = .current) -> Date? {
    let largest = visiblePrayers(witr: witr).map { counts[$0] ?? 0 }.max() ?? 0
    guard largest > 0, perDay > 0 else { return nil }
    let days = (largest + perDay - 1) / perDay
    return calendar.date(byAdding: .day, value: days - 1, to: calendar.startOfDay(for: from))
  }

  /// Hesaplayıcı: başlangıç ve bitiş günü dahil gün sayısı; kadınlar için aylık özel gün düşülür.
  static func owedDays(from start: Date, to end: Date, monthlyExemptDays: Int, calendar: Calendar = .current) -> Int {
    let a = calendar.startOfDay(for: start)
    let b = calendar.startOfDay(for: end)
    guard b >= a else { return 0 }
    let days = (calendar.dateComponents([.day], from: a, to: b).day ?? 0) + 1
    // Ortalama ay 30,44 gün.
    let exempt = Int((Double(days) / 30.44 * Double(Swift.max(0, monthlyExemptDays))).rounded())
    return min(Self.max, Swift.max(0, days - exempt))
  }
}

@MainActor
@Observable
final class KazaStore {
  static let shared = KazaStore()
  private static let cacheKey = "@salah_kaza_v1"
  private static let perDayKey = "@salah_kaza_per_day_v1"

  struct Debt: Codable, Equatable, Sendable {
    var counts: [String: Int] = [:]
    var witr = false
  }

  private struct Cache: Codable {
    var owner: String
    var debt: Debt
  }

  private(set) var debt = Debt()
  private(set) var loaded = false
  private(set) var loading = false
  private(set) var failed = false
  /// Bitiş tahmini için günlük kaza (cihazda).
  var perDay: Int {
    didSet { LocalStore.set("\(perDay)", for: Self.perDayKey) }
  }

  @ObservationIgnored private var pending = 0
  @ObservationIgnored private var owner: String?

  private init() {
    perDay = LocalStore.string(Self.perDayKey).flatMap(Int.init).map { Swift.min(20, Swift.max(1, $0)) } ?? 1
    if let cache = LocalStore.decode(Cache.self, Self.cacheKey) {
      owner = cache.owner
      debt = cache.debt
    }
  }

  /// Ekran ve kart yalnız bu doğruysa görünür.
  var available: Bool {
    AuthStore.shared.isAuthenticated && AppControlStore.shared.supports("kaza") && AppControlStore.shared.isOn("kaza")
  }

  var total: Int { KazaPlan.total(debt.counts, witr: debt.witr) }

  /// Başka hesaba geçildiyse önbellek atılır.
  private func ensureOwner() {
    let current = AuthStore.shared.user?.id
    guard owner != current else { return }
    owner = current
    debt = Debt()
    loaded = false
    LocalStore.remove(Self.cacheKey)
  }

  func fetch() async {
    ensureOwner()
    guard available, !loading, !DebugLaunch.isIsolated else { return }
    struct Response: Decodable { var data: Debt? }
    loading = true
    defer { loading = false }
    do {
      let res = try await APIClient.shared.get("/kaza", as: Response.self)
      // Bu sırada - / + yapıldıysa yanıt eskidir; işlemlerin kendi yanıtı gelir.
      guard pending == 0, let value = res.data else { return }
      apply(value)
      failed = false
    } catch {
      failed = !loaded
    }
  }

  /// - / + düğmesi: iyimser; ağ yoksa kuyruğa.
  func adjust(_ prayer: String, by delta: Int) async {
    ensureOwner()
    guard available, KazaPlan.prayers.contains(prayer), delta != 0 else { return }
    let before = debt.counts[prayer] ?? 0
    let after = Swift.min(KazaPlan.max, Swift.max(0, before + delta))
    guard after != before else { return }
    UsageStore.shared.record("kaza.adjust")
    debt.counts[prayer] = after
    persist()
    guard !DebugLaunch.isIsolated else { return }
    let body: JSONValue = ["prayer": .string(prayer), "delta": .number(Double(after - before))]
    await send("POST", "/kaza/adjust", body)
  }

  /// Hesaplayıcı ya da elle düzeltme: verilen sayaçlar yazılır.
  func setCounts(_ counts: [String: Int]) async {
    ensureOwner()
    guard available else { return }
    for (k, v) in counts where KazaPlan.prayers.contains(k) { debt.counts[k] = Swift.min(KazaPlan.max, Swift.max(0, v)) }
    persist()
    guard !DebugLaunch.isIsolated else { return }
    let payload = JSONValue.object(Dictionary(uniqueKeysWithValues: counts.filter { KazaPlan.prayers.contains($0.key) }.map { ($0.key, JSONValue.number(Double(debt.counts[$0.key] ?? 0))) }))
    await send("PUT", "/kaza", ["counts": payload])
  }

  func setWitr(_ on: Bool) async {
    ensureOwner()
    guard available, debt.witr != on else { return }
    debt.witr = on
    persist()
    guard !DebugLaunch.isIsolated else { return }
    await send("PUT", "/kaza", ["witr": .bool(on)])
  }

  private func send(_ method: String, _ url: String, _ body: JSONValue) async {
    struct Response: Decodable { var data: Debt? }
    pending += 1
    defer { pending -= 1 }
    do {
      let data = try await APIClient.shared.send(method, url, body: body)
      if pending == 1, let value = try? JSONDecoder().decode(Response.self, from: data).data { apply(value) }
    } catch {
      if error.isNetworkError {
        OfflineQueue.shared.enqueue(method: method.lowercased(), url: url, body: body)
      } else {
        Toast.error(t("common.error"), t("kaza.saveFailed"))
        await fetch()
      }
    }
  }

  private func apply(_ value: Debt) {
    debt = value
    loaded = true
    persist()
  }

  private func persist() {
    guard let owner else { return }
    LocalStore.encode(Cache(owner: owner, debt: debt), for: Self.cacheKey)
    GoalsWidgetSync.publish()
  }
}

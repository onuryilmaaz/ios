import Foundation

/// Bugünkü ibadet kayıtları. RN'deki modules/tracker/tracker.store.ts ile aynı
/// davranış ve aynı cache (`@salah_tracker_cache`):
/// - Çevrimdışı eklenen kayıt `offline-` önekli geçici id alır, istek kuyruğa girer
///   (clientRef = geçici id); sunucuya gitmeden silinirse/düzenlenirse kuyruk güncellenir.
/// - Sunucudan liste gelince yalnız HÂLÂ kuyrukta bekleyen offline kayıtlar korunur.
@Observable
final class TrackerStore {
  static let shared = TrackerStore()

  private static let cacheKey = "@salah_tracker_cache"
  private static let offlinePrefix = "offline-"

  private struct Persisted: Codable {
    var todayLogs: [TrackerLog]
    var logsDate: String?
  }

  private struct Envelope: Codable {
    var state: Persisted
    var version: Int = 0
  }

  private(set) var todayLogs: [TrackerLog] = []
  private(set) var isLoading = false
  @ObservationIgnored private var logsDate: String?

  private init() {
    if let env = LocalStore.decode(Envelope.self, Self.cacheKey) {
      todayLogs = env.state.todayLogs
      logsDate = env.state.logsDate
    }
    ensureFreshToday()
  }

  /// Diskten gelen kayıtlar dünden kaldıysa temizler.
  func ensureFreshToday() {
    let today = localDateString()
    guard logsDate != today else { return }
    set([], date: today)
  }

  func fetchTodayLogs() async {
    struct Response: Decodable {
      var success: Bool
      var data: [TrackerLog]?
    }
    isLoading = true
    defer { isLoading = false }
    // Offline: diskteki kayıtlar korunur.
    guard let res = try? await APIClient.shared.get("/tracker/today", as: Response.self), res.success else { return }
    let pending = OfflineQueue.shared.pendingClientRefs()
    let server = (res.data ?? []).filter { $0.type != nil }
    let stillOffline = todayLogs.filter { isOffline($0.id) && pending.contains($0.id) }
    set(server + stillOffline, date: localDateString())
  }

  @discardableResult
  func log(_ type: ActivityType, value: JSONValue, notes: String?) async throws -> TrackerLog? {
    struct Response: Decodable {
      var success: Bool
      var data: TrackerLog?
    }
    var body: [String: JSONValue] = ["activity_type": .string(type.rawValue), "value": value]
    if let notes { body["notes"] = .string(notes) }
    do {
      let res: Response = try await APIClient.shared.post("/tracker", body: .object(body))
      guard res.success, let log = res.data else { return nil }
      set(todayLogs + [log], date: logsDate)
      return log
    } catch where error.isNetworkError {
      let now = Date()
      let date = localDateString(now)
      let tempId = "\(Self.offlinePrefix)\(Int(now.timeIntervalSince1970 * 1000))-\(String(UUID().uuidString.prefix(6)).lowercased())"
      let optimistic = TrackerLog(
        id: tempId, date: date, activity_type: type.rawValue, value: value, notes: notes,
        created_at: ISO8601DateFormatter.withFractionalSeconds.string(from: now))
      set(todayLogs + [optimistic], date: date)
      body["date"] = .string(date)
      OfflineQueue.shared.enqueue(method: "post", url: "/tracker", body: .object(body), clientRef: tempId)
      return optimistic
    }
  }

  func delete(_ id: String) async throws {
    let previous = todayLogs
    set(todayLogs.filter { $0.id != id }, date: logsDate)

    // Sunucuya hiç gitmemiş kayıt: kuyruktaki eklemeyi iptal etmek yeterli.
    if isOffline(id) {
      OfflineQueue.shared.remove(clientRef: id)
      return
    }
    do {
      try await APIClient.shared.send("DELETE", "/tracker/\(id)")
    } catch where error.isNetworkError {
      OfflineQueue.shared.enqueue(method: "delete", url: "/tracker/\(id)", body: nil)
    } catch {
      set(previous, date: logsDate)
      throw error
    }
  }

  /// Çıkışta önceki kullanıcının günlük kayıtları temizlenir.
  func reset() { set([], date: nil) }

  private func isOffline(_ id: String) -> Bool { id.hasPrefix(Self.offlinePrefix) }

  private func set(_ logs: [TrackerLog], date: String?) {
    todayLogs = logs
    logsDate = date
    LocalStore.encode(Envelope(state: Persisted(todayLogs: logs, logsDate: date)), for: Self.cacheKey)
    // İbadet (Amel) widget'ı günün kayıtlarını gösterir.
    if AuthStore.shared.isAuthenticated {
      var seen = Set<String>()
      let types = logs.map(\.activity_type).filter { seen.insert($0).inserted }
      WidgetBridge.updateAmel(types: types, total: logs.count, date: localDateString())
    }
  }
}

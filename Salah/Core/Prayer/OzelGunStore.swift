import Foundation

struct OzelGunAccount: Equatable {
  var id: String
  var gender: String?
}

struct OzelGunPeriod: Codable, Equatable, Sendable {
  var id: String
  var start_date: String
  var end_date: String?
}

struct OzelGunStatus: Codable, Equatable, Sendable {
  var gender: String?
  var todayIsOzelGun: Bool
  var period: OzelGunPeriod?

  func validated() throws -> Self {
    if todayIsOzelGun {
      guard let period, period.end_date == nil, OzelGunDates.date(period.start_date) != nil else { throw OzelGunFailure.invalidResponse }
    }
    return self
  }
}

enum OzelGunFailure: Error { case invalidResponse, unavailable, superseded }

/// Tarihler backend ve RN gibi YYYY-MM-DD; yalnız bellekte tutulur, yeni cache yok.
enum OzelGunDates {
  static func date(_ string: String, calendar: Calendar = HijriMath.gregorianCalendar) -> Date? {
    let parts = string.split(separator: "-").compactMap { Int($0) }
    guard string.count == 10, parts.count == 3, (1...9999).contains(parts[0]), (1...12).contains(parts[1]), (1...31).contains(parts[2]),
      let date = calendar.date(from: .init(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
    let actual = calendar.dateComponents([.year, .month, .day], from: date)
    return actual.year == parts[0] && actual.month == parts[1] && actual.day == parts[2] ? date : nil
  }
  static func daysSince(_ start: String, now: Date = Date(), calendar: Calendar = HijriMath.gregorianCalendar) -> Int? {
    guard let date = date(start, calendar: calendar) else { return nil }
    // RN'nin saat bölme hesabı yerine yerel günler: DST ve sunucu/cihaz gün farkı.
    return max(1, (calendar.dateComponents([.day], from: date, to: calendar.startOfDay(for: now)).day ?? 0) + 1)
  }
}

@MainActor
protocol OzelGunAPI {
  func active() async throws -> OzelGunStatus
  func start() async throws -> OzelGunPeriod
  func end() async throws
}

private struct OzelGunResponse<Value: Decodable>: Decodable {
  var success: Bool
  var data: Value?
}

private struct NativeOzelGunAPI: OzelGunAPI {
  func active() async throws -> OzelGunStatus {
    let response = try await APIClient.shared.get("/ozel-gun/active", as: OzelGunResponse<OzelGunStatus>.self)
    guard response.success, let status = response.data else { throw OzelGunFailure.invalidResponse }
    return try status.validated()
  }
  func start() async throws -> OzelGunPeriod {
    let response: OzelGunResponse<OzelGunPeriod> = try await APIClient.shared.post("/ozel-gun/start")
    guard response.success, let period = response.data, period.end_date == nil,
      OzelGunDates.date(period.start_date) != nil else { throw OzelGunFailure.invalidResponse }
    return period
  }
  func end() async throws {
    let data = try await APIClient.shared.send("POST", "/ozel-gun/end")
    struct Response: Decodable { var success: Bool }
    guard try JSONDecoder().decode(Response.self, from: data).success else { throw OzelGunFailure.invalidResponse }
  }
}

@Observable
final class OzelGunStore {
  static let shared: OzelGunStore = {
    #if DEBUG
    if let mode = DebugLaunch.ozelGun { return OzelGunPreview.make(mode) }
    #endif
    return OzelGunStore(api: NativeOzelGunAPI(), account: {
      AuthStore.shared.user.map { OzelGunAccount(id: $0.id, gender: $0.gender) }
    }, onChanged: {
      guard AuthStore.shared.isAuthenticated, !DebugLaunch.isIsolated else { return }
      await GamificationStore.shared.fetchStats(force: true)
      await GamificationStore.shared.fetchWeeklyStats(force: true)
      await InsightsStore.shared.fetchAll()
    })
  }()

  private var owner: OzelGunAccount?
  private var snapshot: OzelGunStatus?
  private var didLoad = false
  private var fetching = false
  private var mutating = false
  private var failed = false
  @ObservationIgnored private let api: any OzelGunAPI
  @ObservationIgnored private let account: @MainActor () -> OzelGunAccount?
  @ObservationIgnored private let onChanged: @MainActor () async -> Void
  @ObservationIgnored private var revision = 0
  @ObservationIgnored private var readTask: Task<Void, Never>?
  @ObservationIgnored private var readID: UUID?
  @ObservationIgnored private var mutationID: UUID?

  init(api: any OzelGunAPI, account: @escaping @MainActor () -> OzelGunAccount?, onChanged: @escaping @MainActor () async -> Void = {}) {
    self.api = api
    self.account = account
    self.onChanged = onChanged
    owner = account()
  }

  private var current: Bool { owner != nil && owner == account() }
  var userID: String? { account()?.id }
  var gender: String? { current ? (snapshot.map(\.gender) ?? owner?.gender) : account()?.gender }
  var loaded: Bool { current && didLoad }
  var isLoading: Bool { current && (fetching || mutating) }
  var loadFailed: Bool { current && failed }
  var isActive: Bool { current && snapshot?.todayIsOzelGun == true }
  var period: OzelGunPeriod? { current ? snapshot?.period : nil }
  var canManage: Bool { current && loaded && !failed && (gender == "kadin" || isActive) }

  /// Çıkış/hesap/cinsiyet değişiminde eski dönemi hemen gizle; geç yanıtı yok say.
  func syncAccount() {
    let next = account()
    guard next != owner else { return }
    owner = next
    revision += 1
    readTask?.cancel()
    readTask = nil
    readID = nil
    mutationID = nil
    snapshot = nil
    didLoad = false
    fetching = false
    mutating = false
    failed = false
  }

  func fetch() async {
    syncAccount()
    guard let owner, !mutating else { return }
    if let readTask { await readTask.value; return }
    let id = UUID(), version = revision
    fetching = true
    let task = Task {
      do {
        let status = try await api.active().validated()
        guard account() == owner, self.owner == owner, revision == version, !Task.isCancelled else { return }
        snapshot = status
        didLoad = true
        failed = false
      } catch {
        guard account() == owner, self.owner == owner, revision == version, !Task.isCancelled else { return }
        didLoad = true
        failed = true
      }
    }
    readID = id
    readTask = task
    await task.value
    if readID == id { readTask = nil; readID = nil; fetching = false }
  }

  func start() async throws { try await change(starting: true) }
  func end() async throws { try await change(starting: false) }

  private func change(starting: Bool) async throws {
    syncAccount()
    guard let owner, canManage, !mutating, starting != isActive else { throw OzelGunFailure.unavailable }
    guard !starting || gender == "kadin" else { throw OzelGunFailure.unavailable }
    let gender = self.gender
    let id = UUID()
    mutationID = id
    mutating = true
    revision += 1
    readTask?.cancel()
    readTask = nil
    readID = nil
    fetching = false
    defer { if mutationID == id { mutationID = nil; mutating = false } }
    let period: OzelGunPeriod?
    if starting {
      let response = try await api.start()
      guard response.end_date == nil, OzelGunDates.date(response.start_date) != nil else { throw OzelGunFailure.invalidResponse }
      period = response
    } else { try await api.end(); period = nil }
    guard account() == owner, self.owner == owner, mutationID == id else { throw OzelGunFailure.superseded }
    snapshot = .init(gender: gender, todayIsOzelGun: starting, period: period)
    failed = false
    // İstatistik yenilemesi eylem düğmesini bekletmez; hesap değişirse başlamaz.
    Task { if account() == owner { await onChanged() } }
  }
}

#if DEBUG
/// Sahte kullanıcı/sunucu; kayıtlar ve oturum değişmez, tüm yazmalar bellekte.
private final class PreviewOzelGunAPI: OzelGunAPI {
  var status: OzelGunStatus
  init(_ status: OzelGunStatus) { self.status = status }
  func active() async throws -> OzelGunStatus { status }
  func start() async throws -> OzelGunPeriod {
    let calendar = HijriMath.gregorianCalendar
    let day = calendar.dateComponents([.year, .month, .day], from: Date())
    let today = String(format: "%04d-%02d-%02d", day.year!, day.month!, day.day!)
    let period = OzelGunPeriod(id: "preview", start_date: today, end_date: nil)
    status = .init(gender: "kadin", todayIsOzelGun: true, period: period)
    return period
  }
  func end() async throws { status.todayIsOzelGun = false; status.period = nil }
}
private enum OzelGunPreview {
  static func make(_ mode: String) -> OzelGunStore {
    let active = ["active", "confirmEnd", "homeActive", "settingsActive", "changedGender"].contains(mode)
    let gender = ["womenOnly", "changedGender"].contains(mode) ? "erkek" : "kadin"
    let status = OzelGunStatus(gender: gender, todayIsOzelGun: active,
      period: active ? .init(id: "preview", start_date: "2026-10-16", end_date: nil) : nil)
    let api = PreviewOzelGunAPI(status)
    let store = OzelGunStore(api: api, account: { mode == "guest" ? nil : .init(id: "preview", gender: gender) })
    if mode != "loading" { store.seedPreview(status: status, failed: mode == "error") }
    return store
  }
}
extension OzelGunStore {
  fileprivate func seedPreview(status: OzelGunStatus, failed: Bool) {
    snapshot = status
    didLoad = true
    self.failed = failed
  }
}
#endif

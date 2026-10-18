import Foundation
import Testing
@testable import Salah

@MainActor
enum OzelGunFixtures {
  static let user = OzelGunAccount(id: "user-a", gender: "kadin")
  static let period = OzelGunPeriod(id: "period-a", start_date: "2026-10-16", end_date: nil)
  static let inactive = OzelGunStatus(gender: "kadin", todayIsOzelGun: false, period: nil)
  static let active = OzelGunStatus(gender: "kadin", todayIsOzelGun: true, period: period)
  static func waitFor(_ condition: () -> Bool) async throws {
    for _ in 0..<1000 {
      if condition() { return }
      await Task.yield()
    }
    try #require(condition())
  }
}

@MainActor
final class FakeOzelGunAPI: OzelGunAPI {
  var status = OzelGunFixtures.inactive
  var failRead = false, failStart = false, failEnd = false
  var delayReads = false, delayStarts = false
  var reads = 0, starts = 0, ends = 0
  var readGates: [CheckedContinuation<OzelGunStatus, Never>] = []
  var startGates: [CheckedContinuation<OzelGunPeriod, Never>] = []
  func active() async throws -> OzelGunStatus {
    reads += 1
    if failRead { throw URLError(.notConnectedToInternet) }
    if delayReads { return await withCheckedContinuation { readGates.append($0) } }
    return status
  }
  func start() async throws -> OzelGunPeriod {
    starts += 1
    if failStart { throw URLError(.notConnectedToInternet) }
    let period: OzelGunPeriod
    if delayStarts { period = await withCheckedContinuation { startGates.append($0) } }
    else { period = OzelGunFixtures.period }
    status = .init(gender: "kadin", todayIsOzelGun: true, period: period)
    return period
  }
  func end() async throws {
    ends += 1
    if failEnd { throw URLError(.notConnectedToInternet) }
    status = OzelGunFixtures.inactive
  }
}

@MainActor
struct OzelGunDateTests {
  @Test func decodesExistingBackendJSONWithoutExtraStorageFormat() throws {
    let raw = #"{"gender":"kadin","isActive":true,"todayIsOzelGun":true,"period":{"id":"period-a","start_date":"2026-10-16","end_date":null}}"#
    let status = try JSONDecoder().decode(OzelGunStatus.self, from: Data(raw.utf8)).validated()
    #expect(status == OzelGunFixtures.active)
    let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(status.period)) as! [String: Any]
    #expect(json["start_date"] as? String == "2026-10-16")
  }
  @Test func countsCalendarDaysAndRejectsMalformedDates() {
    let cal = NotificationFixtures.calendar
    let now = cal.date(from: .init(year: 2026, month: 10, day: 18, hour: 12))!
    #expect(OzelGunDates.daysSince("2026-10-16", now: now, calendar: cal) == 3)
    #expect(OzelGunDates.daysSince("2026-10-18", now: now, calendar: cal) == 1)
    #expect(OzelGunDates.daysSince("2026-10-19", now: now, calendar: cal) == 1)
    for invalid in ["2026-02-30", "2026-13-01", "2026-00-01", "bad", "2026-1-01", "2026-10-16T00:00:00Z"] {
      #expect(OzelGunDates.date(invalid, calendar: cal) == nil)
    }
  }
  @Test func springDSTDoesNotLoseADay() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/London")!
    let now = cal.date(from: .init(year: 2026, month: 3, day: 30))!
    let start = OzelGunDates.date("2026-03-28", calendar: cal)!
    #expect(now.timeIntervalSince(start) == 47 * 3600)
    #expect(OzelGunDates.daysSince("2026-03-28", now: now, calendar: cal) == 3)
  }
  @Test func invalidActivePeriodCannotEnableProtection() {
    #expect(throws: OzelGunFailure.self) { try OzelGunStatus(gender: "kadin", todayIsOzelGun: true, period: nil).validated() }
    #expect(throws: OzelGunFailure.self) {
      try OzelGunStatus(gender: "kadin", todayIsOzelGun: true, period: .init(id: "p", start_date: "2026-02-30", end_date: nil)).validated()
    }
    #expect(throws: OzelGunFailure.self) {
      try OzelGunStatus(gender: "kadin", todayIsOzelGun: true, period: .init(id: "p", start_date: "2026-10-16", end_date: "2026-10-18")).validated()
    }
  }
}

@MainActor
struct OzelGunStoreTests {
  typealias F = OzelGunFixtures
  func store(_ api: FakeOzelGunAPI) -> OzelGunStore { .init(api: api, account: { F.user }) }

  @Test func startsAndEndsOnlyAfterSuccessfulServerResponses() async throws {
    let api = FakeOzelGunAPI()
    var changes = 0
    let store = OzelGunStore(api: api, account: { F.user }, onChanged: { changes += 1 })
    #expect(!store.loaded && !store.canManage)
    await store.fetch()
    #expect(store.loaded && store.canManage && !store.isActive)
    try await store.start()
    #expect(store.isActive && store.period == F.period && !store.isLoading)
    try await store.end()
    #expect(!store.isActive && store.period == nil && !store.isLoading)
    try await F.waitFor { changes == 2 }
    #expect(api.starts == 1 && api.ends == 1)
  }

  @Test func fetchFailureIsNotMistakenForGenderRestrictionAndCanRetry() async {
    let api = FakeOzelGunAPI()
    api.failRead = true
    let store = store(api)
    await store.fetch()
    #expect(store.loaded && store.loadFailed && !store.canManage && !store.isLoading)
    api.failRead = false
    await store.fetch()
    #expect(!store.loadFailed && store.canManage)
  }

  @Test func failedMutationsPreservePreviousState() async throws {
    let api = FakeOzelGunAPI(), store = store(api)
    await store.fetch()
    api.failStart = true
    await #expect(throws: URLError.self) { try await store.start() }
    #expect(!store.isActive && store.period == nil && !store.isLoading)
    api.failStart = false
    try await store.start()
    api.failEnd = true
    await #expect(throws: URLError.self) { try await store.end() }
    #expect(store.isActive && store.period == F.period && !store.isLoading)
  }

  @Test func blocksGuestWrongGenderAndUnloadedMutations() async throws {
    let api = FakeOzelGunAPI()
    var user: OzelGunAccount?
    let store = OzelGunStore(api: api, account: { user })
    await store.fetch()
    await #expect(throws: OzelGunFailure.self) { try await store.start() }
    #expect(api.reads == 0 && api.starts == 0)
    user = F.user
    await #expect(throws: OzelGunFailure.self) { try await store.start() }
    api.status.gender = "erkek"
    await store.fetch()
    #expect(store.gender == "erkek" && !store.canManage)
    await #expect(throws: OzelGunFailure.self) { try await store.start() }
    api.status.gender = nil
    await store.fetch()
    #expect(store.gender == nil && !store.canManage)
    #expect(api.starts == 0)
  }

  @Test func combinesConcurrentReads() async throws {
    let api = FakeOzelGunAPI(), store = store(api)
    api.delayReads = true
    let first = Task { await store.fetch() }
    try await F.waitFor { api.readGates.count == 1 }
    var secondStarted = false
    let second = Task { secondStarted = true; await store.fetch() }
    try await F.waitFor { secondStarted }
    #expect(api.reads == 1)
    api.readGates[0].resume(returning: F.inactive)
    await first.value
    await second.value
    #expect(store.loaded && !store.isLoading)
  }

  @Test func profileGenderChangeStillAllowsEndingExistingPeriod() async throws {
    let api = FakeOzelGunAPI()
    api.status = .init(gender: "erkek", todayIsOzelGun: true, period: F.period)
    let store = OzelGunStore(api: api, account: { .init(id: "user-a", gender: "erkek") })
    await store.fetch()
    #expect(store.isActive && store.canManage)
    try await store.end()
    #expect(!store.isActive && !store.canManage && store.gender == "erkek")
    await #expect(throws: OzelGunFailure.self) { try await store.start() }
    #expect(api.ends == 1 && api.starts == 0)
  }

  @Test func readStartedBeforeMutationCannotUndoItsResult() async throws {
    let api = FakeOzelGunAPI(), store = store(api)
    await store.fetch()
    api.delayReads = true
    let oldRead = Task { await store.fetch() }
    try await F.waitFor { api.readGates.count == 1 }
    try await store.start()
    api.readGates[0].resume(returning: F.inactive)
    await oldRead.value
    #expect(store.isActive && store.period == F.period && !store.isLoading)
  }

  @Test func ignoresDuplicateMutationWhileRequestIsPending() async throws {
    let api = FakeOzelGunAPI(), store = store(api)
    await store.fetch()
    api.delayStarts = true
    let first = Task { try await store.start() }
    try await F.waitFor { api.startGates.count == 1 }
    await #expect(throws: OzelGunFailure.self) { try await store.start() }
    #expect(api.starts == 1 && store.isLoading && !store.isActive)
    api.startGates[0].resume(returning: F.period)
    try await first.value
    #expect(store.isActive && !store.isLoading)
  }

  @Test func logoutImmediatelyHidesPeriodEvenBeforeAccountSync() async throws {
    let api = FakeOzelGunAPI()
    api.status = F.active
    var user: OzelGunAccount? = F.user
    let store = OzelGunStore(api: api, account: { user })
    await store.fetch()
    #expect(store.isActive && store.period != nil)
    user = nil
    #expect(!store.isActive && store.period == nil && !store.loaded)
    store.syncAccount()
    user = .init(id: "user-b", gender: "erkek")
    store.syncAccount()
    #expect(store.period == nil && !store.loaded && store.gender == "erkek")
  }

  @Test func lateReadAfterAccountOrGenderChangeIsDiscarded() async throws {
    let api = FakeOzelGunAPI()
    var user: OzelGunAccount? = F.user
    let store = OzelGunStore(api: api, account: { user })
    api.delayReads = true
    let oldRead = Task { await store.fetch() }
    try await F.waitFor { api.readGates.count == 1 }
    user?.gender = "erkek"
    store.syncAccount()
    api.readGates[0].resume(returning: F.active)
    await oldRead.value
    #expect(!store.isActive && store.period == nil && !store.loaded)
  }

  @Test func previousAccountsMutationCannotClearNewAccountsBusyState() async throws {
    let api = FakeOzelGunAPI()
    var user: OzelGunAccount? = F.user
    let store = OzelGunStore(api: api, account: { user })
    await store.fetch()
    api.delayStarts = true
    let old = Task { try await store.start() }
    try await F.waitFor { api.startGates.count == 1 }
    user = .init(id: "user-b", gender: "kadin")
    store.syncAccount()
    await store.fetch()
    let next = Task { try await store.start() }
    try await F.waitFor { api.startGates.count == 2 }
    api.startGates[0].resume(returning: F.period)
    await #expect(throws: OzelGunFailure.self) { try await old.value }
    #expect(store.isLoading && store.period == nil)
    let periodB = OzelGunPeriod(id: "period-b", start_date: "2026-10-18", end_date: nil)
    api.startGates[1].resume(returning: periodB)
    try await next.value
    #expect(store.isActive && store.period == periodB && !store.isLoading)
  }
}

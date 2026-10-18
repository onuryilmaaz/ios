import Foundation
import Testing
@testable import Salah

@MainActor
struct AdminTests {
  private func user(_ id: String) -> AdminUser { .init(id: id, email: "\(id)@example.invalid") }
  private func page(_ ids: [String], number: Int = 1, pages: Int = 1) -> AdminAPI.UserList {
    .init(users: ids.map(user), total: ids.count, page: number, totalPages: pages)
  }

  @Test func decodesBothRNRoleAndUserResponseShapes() throws {
    for raw in [#"[{"id":"r","name":"admin"}]"#, #"{"roles":[{"id":"r","name":"admin"}]}"#] {
      #expect(try AdminAPI.decodeRoles(Data(raw.utf8)).first?.name == "admin")
    }
    for raw in [#"{"id":"u","email":"u@example.invalid","roles":["admin"],"isPremium":true,"premiumUntil":null}"#,
      #"{"user":{"id":"u","email":"u@example.invalid","roles":["admin"],"isPremium":true}}"#]
    {
      let value = try AdminAPI.decodeUser(Data(raw.utf8))
      #expect(value.id == "u")
      #expect(value.isPremium == true)
      #expect(value.premiumUntil == nil)
    }
  }

  @Test func malformedRolesAreAnErrorInsteadOfEmptySuccess() {
    #expect(throws: (any Error).self) { try AdminAPI.decodeRoles(Data(#"{"unexpected":[]}"#.utf8)) }
  }

  @Test func roleNamesFollowBackendBoundsAndRNNormalization() {
    #expect(AdminRoleName.clean("  TEST_ROLE\n") == "test_role")
    for value in ["admin", "test_role", String(repeating: "a", count: 50)] { #expect(AdminRoleName.valid(value)) }
    for value in ["", "a", "test-role", "rol2", "Türkçe", String(repeating: "a", count: 51)] { #expect(!AdminRoleName.valid(value)) }
  }

  @Test func searchEncodingCannotInjectAnotherQueryParameter() {
    let encoded = AdminAPI.encode("onur &page=99+?ع")
    let components = URLComponents(string: "https://fixture.invalid/admin/users?search=\(encoded)&page=1")
    #expect(components?.queryItems?.count == 2)
    #expect(components?.queryItems?.first?.value == "onur &page=99+?ع")
  }

  @Test func appendsPagesWithoutDuplicatingUsers() async {
    let store = AdminUsersStore { number, _ in self.page(number == 1 ? ["a", "b"] : ["b", "c"], number: number, pages: 2) }
    await store.load()
    await store.load(append: true)
    #expect(store.users.map(\.id) == ["a", "b", "c"])
    #expect(store.page == 2)
  }

  @Test func searchChangeBeforeDebounceRejectsOldResponseAndPagination() async throws {
    var continuation: CheckedContinuation<AdminAPI.UserList, any Error>?
    var calls = 0
    let store = AdminUsersStore { _, _ in
      calls += 1
      return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    let old = Task { await store.load() }
    try await wait { continuation != nil }
    store.search = "new"
    await store.load(append: true)
    #expect(calls == 1)
    continuation?.resume(returning: page(["old"]))
    await old.value
    #expect(store.users.isEmpty)
    #expect(!store.loading)
  }

  @Test func newerSearchResponseWinsWhenRequestsFinishOutOfOrder() async throws {
    var oldResponse: CheckedContinuation<AdminAPI.UserList, any Error>?
    let store = AdminUsersStore { _, term in
      if term == "old" { return try await withCheckedThrowingContinuation { oldResponse = $0 } }
      return self.page(["new"])
    }
    store.search = "old"
    let old = Task { await store.load() }
    try await wait { oldResponse != nil }
    store.search = "new"
    await store.load()
    oldResponse?.resume(returning: page(["old"]))
    await old.value
    #expect(store.users.map(\.id) == ["new"])
    #expect(!store.loading)
  }

  @Test func duplicateLoadMoreIsCoalesced() async throws {
    var continuation: CheckedContinuation<AdminAPI.UserList, any Error>?
    var calls = 0
    let store = AdminUsersStore { number, _ in
      calls += 1
      if number == 2 { return try await withCheckedThrowingContinuation { continuation = $0 } }
      return self.page(["a"], pages: 2)
    }
    await store.load()
    let pending = Task { await store.load(append: true) }
    try await wait { continuation != nil }
    await store.load(append: true)
    #expect(calls == 2)
    continuation?.resume(returning: page(["b"], number: 2, pages: 2))
    await pending.value
    #expect(store.users.map(\.id) == ["a", "b"])
    #expect(!store.loadingMore)
  }

  @Test func failedRefreshPreservesLoadedUsersAndCanRetry() async {
    var fail = false
    let store = AdminUsersStore { _, _ in
      if fail { throw URLError(.notConnectedToInternet) }
      return self.page(["a"])
    }
    await store.load()
    fail = true
    await store.load()
    #expect(store.failed)
    #expect(store.users.map(\.id) == ["a"])
    fail = false
    await store.load()
    #expect(!store.failed)
  }

  @Test func previewDoesNotPermitMutations() {
    #expect(throws: APIError.self) { try AdminPreview.response("DELETE", "/admin/roles/preview-role") }
  }

  private func wait(_ condition: () -> Bool) async throws {
    for _ in 0..<1000 {
      if condition() { return }
      await Task.yield()
    }
    throw URLError(.timedOut)
  }
}

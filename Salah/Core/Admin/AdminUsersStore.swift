import Foundation

/// Arama/sayfalama RN ile aynı; eski yanıtlar ve tekrarlı alt-sayfa istekleri yok sayılır.
@Observable
final class AdminUsersStore {
  typealias Loader = @MainActor (_ page: Int, _ search: String) async throws -> AdminAPI.UserList
  var search = ""
  private(set) var users: [AdminUser] = []
  private(set) var total = 0
  private(set) var page = 0
  private(set) var totalPages = 1
  private(set) var loading = false
  private(set) var loadingMore = false
  private(set) var failed = false
  @ObservationIgnored private let loader: Loader
  @ObservationIgnored private var revision = 0
  private var loadedSearch: String?
  private var term: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

  init(loader: @escaping Loader = { page, search in try await AdminAPI.users(page: page, search: search) }) {
    self.loader = loader
  }

  func load(append: Bool = false) async {
    if append {
      guard !loading, !loadingMore, page < totalPages, loadedSearch == term else { return }
      loadingMore = true
    } else { loading = true }
    revision += 1
    let request = revision
    let query = term
    let nextPage = append ? page + 1 : 1
    failed = false
    defer {
      if revision == request { loading = false; loadingMore = false }
    }
    do {
      let result = try await loader(nextPage, query)
      guard revision == request, query == term, !Task.isCancelled else { return }
      // Aynı kullanıcı kaydırırken değişen sunucu sayfalarında iki kez gelebilir.
      var seen = Set<String>()
      users = (append ? users + result.users : result.users).filter { seen.insert($0.id).inserted }
      page = result.page
      totalPages = result.totalPages
      total = result.total
      loadedSearch = query
    } catch {
      guard revision == request, query == term, !Task.isCancelled else { return }
      failed = true
    }
  }
}

enum AdminRoleName {
  static func clean(_ name: String) -> String { name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
  static func valid(_ name: String) -> Bool {
    let value = clean(name)
    return (2...50).contains(value.count) && value.wholeMatch(of: /[a-z_]+/) != nil
  }
}

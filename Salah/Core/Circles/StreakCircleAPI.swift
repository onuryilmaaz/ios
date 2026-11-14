import Foundation

/// Birlikte seri: aile ya da arkadaşlarla ortak namaz serisi. Yalnız çevrimiçi, kaynak sunucu (`/streak-circles`).
/// Grup adı serbest metin değil, hazır türlerden biri (`kind`).
@MainActor
enum StreakCircleAPI {
  static let kinds = ["family", "friends", "mosque", "colleagues", "other"]

  struct Summary: Decodable, Identifiable, Hashable {
    var id: String
    var kind: String
    var isOwner: Bool
    var memberCount: Int
    var sharedStreak: Int
    var doneToday: Int
  }
  struct Member: Decodable, Identifiable, Hashable {
    var id: String
    var name: String?
    var isMe: Bool
    var isOwner: Bool
    var today: Int
    var streak: Int
  }
  struct Detail: Decodable, Hashable {
    var id: String
    var kind: String
    var inviteCode: String
    var isOwner: Bool
    var sharedStreak: Int
    var members: [Member]
  }
  private struct ListResponse: Decodable { let data: [Summary]? }
  private struct DetailResponse: Decodable { let data: Detail? }
  struct Empty: Error {}

  /// Davet bağlantısıyla gelen kod (`salah://seri/<kod>`): ekran açılınca katılma alanına yazılır.
  static var pendingCode: String?

  /// Ekran ve giriş noktaları yalnız bu doğruysa görünür.
  static var available: Bool {
    AppControlStore.shared.supports("streakCircles") && AppControlStore.shared.isOn("streak_circles")
  }

  static func list() async throws -> [Summary] {
    try await APIClient.shared.get("/streak-circles", as: ListResponse.self).data ?? []
  }

  static func detail(_ id: String) async throws -> Detail {
    guard let data = try await APIClient.shared.get("/streak-circles/\(id)", as: DetailResponse.self).data else { throw Empty() }
    return data
  }

  static func create(kind: String) async throws -> Detail {
    guard let data = try await APIClient.shared.post("/streak-circles", body: ["kind": .string(kind)], as: DetailResponse.self).data else { throw Empty() }
    return data
  }

  static func join(code: String) async throws -> Detail {
    guard let data = try await APIClient.shared.post("/streak-circles/join", body: ["code": .string(code)], as: DetailResponse.self).data else { throw Empty() }
    return data
  }

  static func removeMember(_ id: String, userId: String) async throws {
    try await APIClient.shared.send("DELETE", "/streak-circles/\(id)/members/\(userId)")
  }

  static func delete(_ id: String) async throws {
    try await APIClient.shared.send("DELETE", "/streak-circles/\(id)")
  }

  /// Sunucu hata kodu → kullanıcı metni.
  static func errorText(_ error: Error) -> String {
    var body = ""
    if case .http(_, let data)? = error as? APIError { body = String(decoding: data, as: UTF8.self) }
    if body.contains("invalid_code") { return t("circles.invalidCode") }
    if body.contains("circle_full") { return t("circles.full") }
    if body.contains("too_many_circles") { return t("circles.tooMany") }
    return t("circles.failed")
  }
}

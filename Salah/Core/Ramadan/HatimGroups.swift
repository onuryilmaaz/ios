import Foundation

/// Grup hatmi: yalnız çevrimiçi, kaynak sunucu.
@MainActor
enum HatimGroupAPI {
  struct Summary: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var round: Int
    var completed: Int
    var isOwner: Bool
    var memberCount: Int
    var doneCount: Int
  }
  struct Member: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var isMe: Bool
  }
  struct Juz: Decodable, Hashable {
    var juz: Int
    var done: Bool
    var userId: String
    var name: String
    var isMine: Bool
  }
  struct Detail: Decodable, Hashable {
    var id: String
    var name: String
    var inviteCode: String
    var round: Int
    var completed: Int
    var ownerId: String
    var isOwner: Bool
    var members: [Member]
    var juz: [Juz]
  }
  private struct ListResponse: Decodable { let data: [Summary]? }
  private struct DetailResponse: Decodable { let data: Detail? }
  struct Empty: Error {}

  /// Davet bağlantısıyla gelen kod: ekran açılınca katılma alanına yazılır.
  static var pendingCode: String?

  /// Medine mushafında cüzlerin başladığı sayfalar.
  private static let juzStartPages = [1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282, 302, 322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582]

  static func pages(ofJuz juz: Int) -> ClosedRange<Int> {
    let index = min(max(juz, 1), 30) - 1
    return juzStartPages[index]...(index == 29 ? 604 : juzStartPages[index + 1] - 1)
  }

  private static var preview: Bool {
    #if DEBUG
    return DebugLaunch.isIsolated && DebugLaunch.ramadan != nil
    #else
    return false
    #endif
  }
  private static var sample = Detail(
    id: "sample", name: "Aile", inviteCode: "K7M2QPXA", round: 2, completed: 1, ownerId: "me", isOwner: true,
    members: [.init(id: "me", name: "Onur Y.", isMe: true), .init(id: "a", name: "Ayşe K.", isMe: false), .init(id: "b", name: "Mehmet", isMe: false)],
    juz: (1...18).map { Juz(juz: $0, done: $0 <= 11, userId: $0 % 3 == 0 ? "me" : "a", name: $0 % 3 == 0 ? "Onur Y." : "Ayşe K.", isMine: $0 % 3 == 0) })

  static func list() async throws -> [Summary] {
    if preview {
      return [.init(id: sample.id, name: sample.name, round: sample.round, completed: sample.completed, isOwner: true, memberCount: sample.members.count, doneCount: sample.juz.filter(\.done).count)]
    }
    return try await APIClient.shared.get("/hatim-groups", as: ListResponse.self).data ?? []
  }

  static func detail(_ id: String) async throws -> Detail {
    if preview { return sample }
    guard let data = try await APIClient.shared.get("/hatim-groups/\(id)", as: DetailResponse.self).data else { throw Empty() }
    return data
  }

  static func create(name: String) async throws -> Detail {
    if preview { return sample }
    guard let data = try await APIClient.shared.post("/hatim-groups", body: ["name": .string(name)], as: DetailResponse.self).data else { throw Empty() }
    return data
  }

  static func join(code: String) async throws -> Detail {
    if preview { return sample }
    guard let data = try await APIClient.shared.post("/hatim-groups/join", body: ["code": .string(code)], as: DetailResponse.self).data else { throw Empty() }
    return data
  }

  static func juz(_ id: String, _ number: Int, action: String) async throws -> Detail {
    if preview {
      switch action {
      case "take": sample.juz = (sample.juz + [Juz(juz: number, done: false, userId: "me", name: "Onur Y.", isMine: true)]).sorted { $0.juz < $1.juz }
      case "release": sample.juz.removeAll { $0.juz == number }
      default:
        if let i = sample.juz.firstIndex(where: { $0.juz == number }) { sample.juz[i].done = action == "done" }
      }
      return sample
    }
    guard let data = try await APIClient.shared.post("/hatim-groups/\(id)/juz/\(number)", body: ["action": .string(action)], as: DetailResponse.self).data else { throw Empty() }
    return data
  }

  static func removeMember(_ id: String, userId: String) async throws {
    if preview { return }
    try await APIClient.shared.send("DELETE", "/hatim-groups/\(id)/members/\(userId)")
  }

  static func delete(_ id: String) async throws {
    if preview { return }
    try await APIClient.shared.send("DELETE", "/hatim-groups/\(id)")
  }

  static func errorText(_ error: Error) -> String {
    var body = ""
    if case .http(_, let data)? = error as? APIError { body = String(decoding: data, as: UTF8.self) }
    if body.contains("invalid_code") { return t("hatimGroups.invalidCode") }
    if body.contains("group_full") { return t("hatimGroups.full") }
    if body.contains("too_many_groups") { return t("hatimGroups.tooMany") }
    if body.contains("juz_taken") { return t("hatimGroups.taken") }
    return t("hatimGroups.failed")
  }
}

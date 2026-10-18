import Foundation

struct Dua: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let title: String
  let arabic: String
  /// Arapça arayüzde boş (Arapça metin anlamın kendisi).
  let transliteration: String
  /// Seçili dildeki anlam (alan adı RN ile aynı); Arapça arayüzde boş.
  let turkish: String
  let source: String?
}

struct DuaCategory: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let title: String
  let icon: String
  let duas: [Dua]
}

struct DuaSituation: Codable, Equatable, Identifiable, Sendable {
  let key: String
  let icon: String
  let duaIds: [String]
  let label: String
  let keywords: [String]
  var id: String { key }
}

/// Dualar ve kategorileri seçili dilde. Veri RN ile ortak kaynaktan üretilir:
/// mobile/src/data/duas.ts + duas.i18n.ts → `bun ios/scripts/gen-duas.ts`.
enum DuaLibrary {
  private struct Language: Decodable {
    let categories: [DuaCategory]
    let situations: [DuaSituation]
  }

  private static let all: [String: Language] = {
    guard let url = Bundle.main.url(forResource: "duas.generated", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return [:] }
    return (try? JSONDecoder().decode([String: Language].self, from: data)) ?? [:]
  }()

  private static var current: Language? { all[Localizer.shared.language.rawValue] ?? all["tr"] }

  static var categories: [DuaCategory] { current?.categories ?? [] }
  static var situations: [DuaSituation] { current?.situations ?? [] }
  static var allDuas: [Dua] { categories.flatMap(\.duas) }

  static func duas(ids: [String]) -> [Dua] {
    let byId = Dictionary(allDuas.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    return ids.compactMap { byId[$0] }
  }

  /// Serbest metni seçili dilin anahtar kelimeleriyle bir duruma eşler (AI kapalıyken).
  /// En çok anahtar kelime içeren durum kazanır. RN: `matchLocalizedSituation`.
  static func matchSituation(_ text: String) -> DuaSituation? {
    let lowered = text.lowercased(with: Localizer.shared.locale)
    var best: (situation: DuaSituation, score: Int)?
    for situation in situations {
      let score = situation.keywords.filter { lowered.contains($0) }.count
      if score > 0, score > (best?.score ?? 0) { best = (situation, score) }
    }
    return best?.situation
  }

  /// AI dua önerisi (Gemini). `nil` → AI kapalı/başarısız; çağıran anahtar kelimeye düşer.
  static func suggest(feeling: String) async -> (message: String, duas: [Dua])? {
    struct Response: Decodable {
      struct Payload: Decodable {
        let message: String?
        let ids: [String]?
      }
      let data: Payload?
    }
    let catalog = allDuas.map { JSONValue.object(["id": .string($0.id), "title": .string($0.title)]) }
    guard
      let res = try? await APIClient.shared.post(
        "/assistant/dua-suggest",
        body: ["feeling": .string(feeling), "duas": .array(catalog), "language": .string(Localizer.shared.language.rawValue)],
        as: Response.self),
      let payload = res.data
    else { return nil }
    let duas = duas(ids: payload.ids ?? [])
    return duas.isEmpty ? nil : (payload.message ?? "", duas)
  }
}

/// Favori dualar (RN ile aynı anahtar: `DUA_FAVORITES`, id dizisi).
@Observable
final class DuaFavorites {
  static let shared = DuaFavorites()
  private static let key = "DUA_FAVORITES"

  private(set) var ids: Set<String>

  private init() {
    ids = Set(LocalStore.decode([String].self, Self.key) ?? [])
  }

  func contains(_ id: String) -> Bool { ids.contains(id) }

  func toggle(_ id: String) {
    if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    LocalStore.encode(Array(ids), for: Self.key)
  }
}

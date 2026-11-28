import Foundation

/// Konuya bağlı ayet: sure, ilk ve son ayet (çoğunlukla aynı).
struct TopicRef: Codable, Hashable, Identifiable {
  let s: Int
  let a: Int
  let to: Int

  init(s: Int, a: Int, to: Int? = nil) {
    self.s = s
    self.a = a
    self.to = max(a, to ?? a)
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let s = try c.decode(Int.self, forKey: .s), a = try c.decode(Int.self, forKey: .a)
    self.init(s: s, a: a, to: try c.decodeIfPresent(Int.self, forKey: .to))
  }

  var id: String { "\(s):\(a):\(to)" }

  init?(id: String) {
    let parts = id.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 3, parts[0] > 0, parts[1] > 0 else { return nil }
    self.init(s: parts[0], a: parts[1], to: parts[2])
  }
}

struct Topic: Decodable, Identifiable {
  let id: String
  let icon: String
  let verses: [TopicRef]

  var title: String { t("topics.\(id).title") }
  var sub: String { t("topics.\(id).sub") }
}

/// `Resources/topics.json`: konu başına ayet listesi. Ayet sayısı ve sırası dosyaya bağlıdır, kodda sabit değildir.
enum TopicCatalog {
  private struct File: Decodable { let topics: [Topic] }

  static let all: [Topic] = {
    guard let url = Bundle.main.url(forResource: "topics", withExtension: "json"), let data = try? Data(contentsOf: url),
      let file = try? JSONDecoder().decode(File.self, from: data)
    else { return [] }
    return file.topics
  }()

  static func topic(_ id: String) -> Topic? { all.first { $0.id == id } }

  /// Seçili konuların benzersiz ayetleri (konu sırasıyla). Bilinmeyen konu kimlikleri atlanır.
  static func refs(for ids: [String]) -> [TopicRef] {
    var seen = Set<String>()
    return ids.compactMap { topic($0) }.flatMap(\.verses).filter { seen.insert($0.id).inserted }
  }

  /// Kaydedilmiş ve bilinen konu kimlikleri; silinmiş konular elenir.
  static func valid(_ ids: [String]) -> [String] {
    var seen = Set<String>()
    return ids.filter { topic($0) != nil && seen.insert($0).inserted }
  }
}

/// Bir konu ayetinin ekrana hazır hali (birden çok ayetlik aralık birleştirilir).
struct TopicVerseText: Equatable, Identifiable {
  let ref: TopicRef
  let arabic: String
  let text: String
  /// "Bakara 153" ya da "Bakara 153-155".
  let source: String
  let page: Int?
  var id: String { ref.id }
}

enum TopicVerses {
  /// Çok uzun aralıklar kart ve bildirim için kısaltılır.
  static let maxRange = 4

  static func load(_ ref: TopicRef) async -> TopicVerseText? {
    guard let surah = await QuranService.surahs().first(where: { $0.id == ref.s }) else { return nil }
    var verses: [Verse] = []
    for number in ref.a...min(ref.to, ref.a + maxRange - 1) {
      guard let verse = await QuranService.verse(surahId: ref.s, verseNumber: number) else { return nil }
      verses.append(verse)
    }
    guard let first = verses.first, let last = verses.last else { return nil }
    let range = first.verse_number == last.verse_number ? "\(first.verse_number)" : "\(first.verse_number)-\(last.verse_number)"
    return TopicVerseText(
      ref: ref,
      arabic: verses.map(\.verse_simplified).joined(separator: " "),
      text: verses.map { $0.translation.text.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: " "),
      source: t("topics.ref", ["surah": surahName(surah), "verse": range]),
      page: first.page_number)
  }
}

/// Günün ilhamı, bildirim ve widget için seçili konulardan ayet seçimi.
enum TopicPicker {
  /// Tarihe bağlı, kararlı karıştırma: aynı gün aynı sıra (Swift'in rastgele hash'i kullanılmaz).
  static func shuffled(_ refs: [TopicRef], seed: String) -> [TopicRef] {
    var state: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in seed.utf8 { state = (state ^ UInt64(byte)) &* 0x100_0000_01b3 }
    func next() -> UInt64 {
      state &+= 0x9e37_79b9_7f4a_7c15
      var z = state
      z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
      z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
      return z ^ (z >> 31)
    }
    var out = refs
    guard out.count > 1 else { return out }
    for i in stride(from: out.count - 1, to: 0, by: -1) { out.swapAt(i, Int(next() % UInt64(i + 1))) }
    return out
  }

  /// O gün için en çok `count` ayet (günlük içerik: widget 4 saatlik dilimlerde gezer).
  static func day(_ topicIDs: [String], date: String, count: Int = TopicDay.maxItems) -> [TopicRef] {
    Array(shuffled(TopicCatalog.refs(for: topicIDs), seed: date + "|" + topicIDs.sorted().joined(separator: ",")).prefix(count))
  }
}

enum TopicDay {
  /// Widget günü 4 saatlik 6 dilime böler.
  static let maxItems = 6
}

/// Kaydedilen konu ayetleri (yer imi). Yerel depo, `@salah_topic_saved_v1`: ayet kimlikleri ("2:153:153") listesi.
@Observable
final class TopicSavedStore {
  static let shared = TopicSavedStore()
  static let key = "@salah_topic_saved_v1"

  private(set) var ids: [String]

  init() { ids = LocalStore.decode([String].self, Self.key) ?? [] }

  /// En son kaydedilen en üstte.
  var refs: [TopicRef] { ids.compactMap { TopicRef(id: $0) } }
  func isSaved(_ ref: TopicRef) -> Bool { ids.contains(ref.id) }

  func toggle(_ ref: TopicRef) {
    if let index = ids.firstIndex(of: ref.id) { ids.remove(at: index) } else { ids.insert(ref.id, at: 0) }
    LocalStore.encode(ids, for: Self.key)
  }
}

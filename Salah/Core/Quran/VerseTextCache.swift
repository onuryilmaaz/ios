import Foundation

/// Konu, günün okuması, widget, Siri ve Zikirler'in ortak ayet yükleyicisi: seçili dilin metni bellekte ve yerelde saklanır,
/// ağ yoksa son çekilen kullanılır. Aralık sınırı çağırana bağlıdır (Zikirler'de Nâs'ın 6 ayeti de gelir).
enum VerseTextCache {
  private struct Entry: Codable {
    var arabic: String
    var text: String
    var source: String
    var page: Int?
  }

  private static let key = "@salah_verse_text_cache_v1"
  private static let maxEntries = 80
  @MainActor private static var memory: [String: Entry]?

  private static func cacheKey(_ ref: TopicRef, limit: Int) -> String {
    "\(Localizer.shared.language.rawValue)|\(ref.s):\(ref.a):\(min(ref.to, ref.a + limit - 1))"
  }

  @MainActor
  static func cached(_ ref: TopicRef, limit: Int = TopicVerses.maxRange) -> TopicVerseText? {
    if memory == nil { memory = LocalStore.decode([String: Entry].self, key) ?? [:] }
    return memory?[cacheKey(ref, limit: limit)].map { make(ref, $0) }
  }

  @MainActor
  static func load(_ ref: TopicRef, limit: Int = TopicVerses.maxRange) async -> TopicVerseText? {
    if let hit = cached(ref, limit: limit) { return hit }
    guard let surah = await QuranService.surahs().first(where: { $0.id == ref.s }) else { return nil }
    var verses: [Verse] = []
    for number in ref.a...min(ref.to, ref.a + limit - 1) {
      guard let verse = await QuranService.verse(surahId: ref.s, verseNumber: number) else { return nil }
      verses.append(verse)
    }
    guard let first = verses.first, let last = verses.last else { return nil }
    let range = first.verse_number == last.verse_number ? "\(first.verse_number)" : "\(first.verse_number)-\(last.verse_number)"
    let entry = Entry(
      arabic: verses.map(\.verse_simplified).joined(separator: " "),
      text: verses.map { $0.translation.text.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: " "),
      source: t("topics.ref", ["surah": surahName(surah), "verse": range]), page: first.page_number)
    guard !entry.text.isEmpty || !entry.arabic.isEmpty else { return nil }
    store(entry, for: cacheKey(ref, limit: limit))
    return make(ref, entry)
  }

  @MainActor
  private static func store(_ entry: Entry, for cacheKey: String) {
    guard !DebugLaunch.isIsolated else { return }
    var all = memory ?? LocalStore.decode([String: Entry].self, key) ?? [:]
    all[cacheKey] = entry
    if all.count > maxEntries {
      let language = Localizer.shared.language.rawValue + "|"
      all = all.filter { $0.key.hasPrefix(language) }
    }
    memory = all
    LocalStore.encode(all, for: key)
  }

  private static func make(_ ref: TopicRef, _ entry: Entry) -> TopicVerseText {
    TopicVerseText(ref: ref, arabic: entry.arabic, text: entry.text, source: entry.source, page: entry.page)
  }
}

/// Ayet sesi: konu, kıssa, günün okuması ve Zikirler'de tek ayet ya da aralık çalar (mevcut `QuranAudioPlayer`, seçili kâri).
enum VerseAudio {
  /// Aralığın her ayeti tek tek.
  static func refs(surah: Int, from: Int, to: Int) -> [TopicRef] {
    guard from > 0, to >= from else { return [] }
    return (from...to).map { TopicRef(s: surah, a: $0) }
  }

  /// Ses kaynağının beklediği genel ayet numarası (1...6236) ile ayet listesi; metin gerekmez.
  @MainActor
  static func verses(_ refs: [TopicRef]) async -> [Verse] {
    let surahs = await QuranService.surahs().sorted { $0.id < $1.id }
    guard !surahs.isEmpty else { return [] }
    var offsets: [Int: Int] = [:]
    var total = 0
    for surah in surahs { offsets[surah.id] = total; total += surah.verse_count }
    return refs.compactMap { ref in
      guard let base = offsets[ref.s], ref.a > 0 else { return nil }
      return Verse(id: base + ref.a, surah_id: ref.s, verse_number: ref.a, verse_simplified: "", page_number: nil, juz_number: nil,
                   transcription: nil, translation: .init(id: nil, text: "", author: nil))
    }
  }
}

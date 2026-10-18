import Foundation
import Testing
@testable import Salah

@MainActor
struct MushafLayoutTests {
  func page(_ n: Int) throws -> MushafPage {
    let url = try #require(Bundle.main.url(forResource: "mushaf-pages", withExtension: "json"))
    let fixtures = try JSONDecoder().decode([String: [MushafAPIVerse]].self, from: Data(contentsOf: url))
    return try MushafLayout.build(page: n, verses: #require(fixtures[String(n)]))
  }
  /// RN services/__tests__/mushaf.test.ts: aynı gerçek quran.com örnekleri.
  @Test func fatihaIsCenteredAndBasmalaIsVerseOne() throws {
    let p = try page(1)
    #expect(p.centered && p.lines.first == .init(kind: "header", surahId: 1))
    #expect(!p.lines.contains { $0.kind == "basmala" })
    #expect(p.lines.flatMap { $0.words ?? [] }.first?.verse == "1:1")
  }
  @Test func baqarahHasHeaderAndBasmala() throws {
    let p = try page(2)
    #expect(p.centered && p.lines.prefix(2).map(\.kind) == ["header", "basmala"])
  }
  @Test(arguments: [76, 77, 187, 604]) func normalPagesHaveFifteenLines(number: Int) throws {
    #expect(try page(number).lines.count == 15)
  }
  @Test func trailingHeaderAndNextPageBasmala() throws {
    #expect(try page(76).lines[14] == .init(kind: "header", surahId: 4))
    #expect(try page(77).lines[0] == .init(kind: "basmala"))
  }
  @Test func tawbahHasNoBasmala() throws {
    let p = try page(187)
    #expect(p.lines.first == .init(kind: "header", surahId: 9))
    #expect(!p.lines.contains { $0.kind == "basmala" })
  }
  @Test func lastPageContainsThreeSurahsEachWithBasmala() throws {
    let p = try page(604)
    let indices = p.lines.indices.filter { p.lines[$0].kind == "header" }
    #expect(indices.compactMap { p.lines[$0].surahId } == [112, 113, 114])
    for index in indices { #expect(p.lines[index + 1].kind == "basmala") }
  }
  @Test func wordsAndEndMarkersKeepVerseIdentity() throws {
    let words = try page(77).lines.flatMap { $0.words ?? [] }
    #expect(words.contains { $0.isEnd } && words.contains { !$0.isEnd })
    #expect(words.allSatisfy { $0.verse.range(of: #"^\d+:\d+$"#, options: .regularExpression) != nil })
    let ends = words.filter(\.isEnd).map(\.verse)
    #expect(Set(ends).count == ends.count)
  }
  @Test func cacheShapeMatchesRN() throws {
    let p = try page(77)
    let raw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as! [String: Any]
    #expect(raw["page"] as? Int == 77 && raw["centered"] as? Bool == false)
    let lines = raw["lines"] as! [[String: Any]]
    #expect(lines[0]["kind"] as? String == "basmala")
    #expect(lines[1]["words"] is [[String: Any]])
    #expect(try JSONDecoder().decode(MushafPage.self, from: JSONEncoder().encode(p)) == p)
  }
  @Test func invalidInputDoesNotCrash() {
    #expect(throws: MushafLayout.Failure.self) { try MushafLayout.build(page: 0, verses: []) }
    #expect(throws: MushafLayout.Failure.self) { try MushafLayout.build(page: 1, verses: []) }
    let verse = MushafAPIVerse(verse_key: "2:1", verse_number: 1, juz_number: 1, words: [.init(char_type_name: "word", line_number: 99, text_qpc_hafs: "text")])
    #expect(throws: MushafLayout.Failure.self) { try MushafLayout.build(page: 2, verses: [verse]) }
  }
}

@MainActor
struct QuranReadingTests {
  @Test func restoresRNProgressAndSettings() {
    let entries = ["QURAN_LAST_READ": #"{"surahId":2,"surahName":"Bakara","verseNumber":12,"updatedAt":1792000000000}"#,
      "QURAN_MUSHAF_PAGE": "77", "QURAN_MUSHAF_MARK": #"{"page":77,"line":3}"#, "QURAN_MUSHAF_THEME": "sepia",
      "QURAN_SETTINGS_V2": #"{"fontSize":"xl","readingTheme":"night","layoutMode":"mushaf","tajweed":true}"#]
    let store = QuranReadingStore(get: { entries[$0] }, write: { _, _ in })
    #expect(store.lastRead?.verseNumber == 12 && store.lastRead?.updatedAt == 1792000000000)
    #expect(store.mushafPage == 77 && store.mushafMark == .init(page: 77, line: 3))
    #expect(store.mushafTheme == .sepia && store.settings.fontSize == .xl && store.settings.tajweed)
    #expect(store.settings.readingTheme == .night && store.settings.layoutMode == .mushaf)
  }
  @Test func corruptFieldsFallBackIndependently() {
    let entries = ["QURAN_MUSHAF_PAGE": "9999", "QURAN_MUSHAF_MARK": #"{"page":1,"line":99}"#,
      "QURAN_MUSHAF_THEME": "unknown", "QURAN_SETTINGS_V2": #"{"fontSize":"bad","tajweed":true}"#]
    let store = QuranReadingStore(get: { entries[$0] }, write: { _, _ in })
    #expect(store.mushafPage == nil && store.mushafMark == nil && store.mushafTheme == .auto)
    #expect(store.settings.fontSize == .md && store.settings.readingTheme == .system && store.settings.tajweed)
  }
  @Test func writesCompatibleJSONAndTogglesSingleMark() throws {
    var saved: [String: String] = [:]
    let store = QuranReadingStore(get: { _ in nil }, write: { saved[$0] = $1 })
    store.setPage(605)
    #expect(saved["QURAN_MUSHAF_PAGE"] == "604")
    store.toggleMark(page: 77, line: 3)
    let mark = try JSONDecoder().decode(QuranReadingStore.Mark.self, from: Data(#require(saved["QURAN_MUSHAF_MARK"]).utf8))
    #expect(mark == .init(page: 77, line: 3))
    store.toggleMark(page: 78, line: 4)
    #expect(store.mushafMark == .init(page: 78, line: 4))
    store.toggleMark(page: 78, line: 4)
    #expect(saved["QURAN_MUSHAF_MARK"] == nil && store.mushafMark == nil)
    store.setLastRead(surahId: 2, name: "Bakara", verse: 3, now: Date(timeIntervalSince1970: 1000))
    #expect(store.lastRead?.updatedAt == 1000000)
    store.updateSettings { $0.tajweed = true }
    let settings = try JSONDecoder().decode(QuranReadingSettings.self, from: Data(#require(saved["QURAN_SETTINGS_V2"]).utf8))
    #expect(settings.tajweed)
  }
}

@MainActor
struct QuranSearchAndAudioTests {
  @Test func normalizesTurkishAndArabicDigits() {
    #expect(QuranSearch.normalize(" ŞÜKÜR ÂLİM ı ") == "sukur alim i")
    #expect(QuranSearch.normalize("١٢") == "12")
  }
  @Test func verseSearchUsesNumberMeaningOrTranscription() {
    let v = Verse(id: 10, surah_id: 2, verse_number: 3, verse_simplified: "", page_number: nil, juz_number: nil,
      transcription: "Şükür", translation: .init(id: nil, text: "Güzel öğüt", author: nil))
    #expect(QuranSearch.verses([v], query: "sukur") == [v])
    #expect(QuranSearch.verses([v], query: "ogut") == [v])
    #expect(QuranSearch.verses([v], query: "٣") == [v])
    #expect(QuranSearch.verses([v], query: "30").isEmpty)
  }
  @Test func audioUsesGlobalVerseIdAndCompletionRules() {
    #expect(QuranAudioSequence.url(globalVerseID: 8, reciter: "ar.alafasy")?.absoluteString.hasSuffix("/ar.alafasy/8.mp3") == true)
    #expect(QuranAudioSequence.url(globalVerseID: 0, reciter: "ar.alafasy") == nil)
    #expect(QuranAudioSequence.next(index: 0, count: 7, repeatMode: .off) == 1)
    #expect(QuranAudioSequence.next(index: 6, count: 7, repeatMode: .off) == nil)
    #expect(QuranAudioSequence.next(index: 6, count: 7, repeatMode: .surah) == 0)
    #expect(QuranAudioSequence.next(index: 3, count: 7, repeatMode: .single) == 3)
    #expect(QuranAudioSequence.next(index: 0, count: 0, repeatMode: .single) == nil)
  }
  @Test func tajweedPreservesTextAndEndMarker() {
    let segments = TajweedParser.parse(#"a<tajweed class=ghunnah>ب</tajweed><span class="end">١</span>z"#)
    #expect(segments.map(\.text).joined() == "aب١z")
    #expect(segments.map(\.rule) == [nil, "ghunnah", "end", nil])
  }
  /// RN components/share/__tests__/fitText.test.ts ile aynı girdiler.
  @Test func shareTextFitsAtSentenceOrWordBoundary() {
    #expect(QuranShareText.fit("Kısa  bir\nmetin") == "Kısa bir metin")
    let text = String(repeating: "Birinci cümle burada biter. ", count: 30) + "Son."
    let sentence = QuranShareText.fit(text, max: 200)
    #expect(sentence.count <= 202 && sentence.hasSuffix("biter. …"))
    let words = QuranShareText.fit(String(repeating: "kelime ", count: 100), max: 50)
    #expect(words.range(of: #"^(kelime )+…$"#, options: .regularExpression) != nil)
  }
}

import Foundation

enum QuranFontSize: String, Codable, CaseIterable { case sm, md, lg, xl
  var scale: Double { switch self { case .sm: 0.85; case .md: 1; case .lg: 1.18; case .xl: 1.38 } }
  var labelKey: String { "quranSettings.font\(rawValue.capitalized)" }
}
enum QuranReadingTheme: String, Codable, CaseIterable { case system, sepia, night
  var labelKey: String { "mushaf.themes.\(self == .system ? "auto" : rawValue)" }
}
enum QuranLayout: String, Codable { case verses, mushaf }
enum MushafTheme: String, Codable, CaseIterable { case auto, light, sepia, night }

struct QuranReadingSettings: Codable, Equatable {
  var fontSize: QuranFontSize = .md
  var readingTheme: QuranReadingTheme = .system
  var layoutMode: QuranLayout = .verses
  var tajweed = false

  init() {}
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    fontSize = (try? c.decode(QuranFontSize.self, forKey: .fontSize)) ?? .md
    readingTheme = (try? c.decode(QuranReadingTheme.self, forKey: .readingTheme)) ?? .system
    layoutMode = (try? c.decode(QuranLayout.self, forKey: .layoutMode)) ?? .verses
    tajweed = (try? c.decode(Bool.self, forKey: .tajweed)) ?? false
  }
}

@Observable
final class QuranReadingStore {
  static let shared = QuranReadingStore()
  struct LastRead: Codable, Equatable {
    var surahId: Int
    var surahName: String
    var verseNumber: Int
    var updatedAt: Double
  }
  struct Mark: Codable, Equatable { var page: Int; var line: Int }

  private(set) var lastRead: LastRead?
  private(set) var mushafPage: Int?
  private(set) var mushafMark: Mark?
  private(set) var mushafTheme: MushafTheme = .auto
  private(set) var settings: QuranReadingSettings = .init()
  @ObservationIgnored private let write: (String, String?) -> Void

  init(get: (String) -> String? = { LocalStore.string($0) },
       write: @escaping (String, String?) -> Void = {
         if !DebugLaunch.isIsolated { LocalStore.set($1, for: $0) }
       }) {
    self.write = write
    func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
      get(key).flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
    lastRead = decode(LastRead.self, "QURAN_LAST_READ")
    if let lr = lastRead, !(1...114).contains(lr.surahId) || lr.verseNumber < 1 { lastRead = nil }
    mushafPage = get("QURAN_MUSHAF_PAGE").flatMap(Int.init).flatMap { (1...604).contains($0) ? $0 : nil }
    mushafMark = decode(Mark.self, "QURAN_MUSHAF_MARK")
    if let mark = mushafMark, !(1...604).contains(mark.page) || !(0..<15).contains(mark.line) { mushafMark = nil }
    mushafTheme = get("QURAN_MUSHAF_THEME").flatMap(MushafTheme.init(rawValue:)) ?? .auto
    settings = decode(QuranReadingSettings.self, "QURAN_SETTINGS_V2") ?? .init()
  }

  func setLastRead(surahId: Int, name: String, verse: Int, now: Date = Date()) {
    guard (1...114).contains(surahId), verse > 0 else { return }
    lastRead = .init(surahId: surahId, surahName: name, verseNumber: verse, updatedAt: now.timeIntervalSince1970 * 1000)
    save(lastRead, key: "QURAN_LAST_READ")
  }
  func setPage(_ page: Int) {
    mushafPage = min(604, max(1, page))
    write("QURAN_MUSHAF_PAGE", String(mushafPage!))
  }
  func toggleMark(page: Int, line: Int) {
    guard (1...604).contains(page), (0..<15).contains(line) else { return }
    let mark = Mark(page: page, line: line)
    mushafMark = mushafMark == mark ? nil : mark
    if let mushafMark { save(mushafMark, key: "QURAN_MUSHAF_MARK") }
    else { write("QURAN_MUSHAF_MARK", nil) }
  }
  func setTheme(_ theme: MushafTheme) { mushafTheme = theme; write("QURAN_MUSHAF_THEME", theme.rawValue) }
  func updateSettings(_ change: (inout QuranReadingSettings) -> Void) {
    change(&settings)
    save(settings, key: "QURAN_SETTINGS_V2")
  }
  private func save<T: Encodable>(_ value: T, key: String) {
    if let data = try? JSONEncoder().encode(value) { write(key, String(data: data, encoding: .utf8)) }
  }
}

enum QuranSearch {
  static func normalize(_ text: String) -> String {
    let replacements = ["ı": "i", "â": "a", "ā": "a", "î": "i", "ī": "i", "û": "u", "ū": "u", "ö": "o", "ô": "o", "ü": "u", "ş": "s", "ç": "c", "ğ": "g"]
    var result = text.lowercased().replacingOccurrences(of: "\u{0307}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    for (from, to) in replacements { result = result.replacingOccurrences(of: from, with: to) }
    return String(result.map { character in character.wholeNumberValue.map { Character(String($0)) } ?? character })
  }
  static func surahs(_ surahs: [Surah], query: String) -> [Surah] {
    let q = normalize(query)
    guard !q.isEmpty else { return surahs }
    return surahs.filter { normalize($0.name).contains(q) || normalize(surahName($0)).contains(q) || ($0.name_arabic ?? "").contains(q) || String($0.id).contains(q) }
  }
  static func verses(_ verses: [Verse], query: String) -> [Verse] {
    let q = normalize(query)
    guard !q.isEmpty else { return verses }
    return verses.filter { String($0.verse_number) == q || normalize($0.translation.text).contains(q) || normalize($0.transcription ?? "").contains(q) }
  }
}

enum QuranRepeatMode: String, CaseIterable { case off, single, surah }
enum QuranAudioSequence {
  static func next(index: Int, count: Int, repeatMode: QuranRepeatMode) -> Int? {
    guard count > 0, index >= 0, index < count else { return nil }
    if repeatMode == .single { return index }
    if index + 1 < count { return index + 1 }
    return repeatMode == .surah ? 0 : nil
  }
  static func url(globalVerseID: Int, reciter: String) -> URL? {
    guard (1...6236).contains(globalVerseID), ["ar.alafasy", "ar.abdullahbasfar"].contains(reciter) else { return nil }
    return URL(string: "https://cdn.islamic.network/quran/audio/128/\(reciter)/\(globalVerseID).mp3")
  }
}

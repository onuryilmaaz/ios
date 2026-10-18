import Foundation

struct Surah: Codable, Equatable, Identifiable, Sendable {
  let id: Int
  let name: String
  let verse_count: Int
  let page_number: Int?
  let revelation_order: Int?
  let revelation_place: String?
  let name_arabic: String?
}

struct Verse: Codable, Equatable, Identifiable, Sendable {
  struct Translation: Codable, Equatable, Sendable {
    struct Author: Codable, Equatable, Sendable {
      /// Meal slug'ı (`diyanet`, `elmalili`…) ya da yabancı dilde `en`/`ar`.
      var id: String
      var name: String
    }
    var id: Int?
    var text: String
    var author: Author?
  }

  let id: Int
  let surah_id: Int
  let verse_number: Int
  let verse_simplified: String
  let page_number: Int?
  let juz_number: Int?
  let transcription: String?
  var translation: Translation
}

/// Kur'an verisi. RN'deki services/quran.service.ts ile aynı kaynaklar ve cache anahtarları:
/// - Metin ve Türkçe meal kendi backend'imizden (`/quran/*`).
/// - İngilizce anlam: Sahih International, Arapça: et-Tefsîru'l-Müyesser (quran.com).
enum QuranService {
  private static let surahsCacheKey = "@salah_surahs_cache_v2"
  private static var memoSurahs: [Surah]?
  private static var meaningTasks: [String: Task<[Int: String], Never>] = [:]

  static let foreignMeaningSource: [AppLanguage: String] = [
    .en: "Saheeh International",
    .ar: "التفسير الميسر",
  ]

  static func surahs() async -> [Surah] {
    #if DEBUG
    if DebugLaunch.quran != nil { return QuranPreview.surahs }
    #endif
    if let memoSurahs { return memoSurahs }
    if let cached = LocalStore.decode([Surah].self, surahsCacheKey), !cached.isEmpty {
      memoSurahs = cached
      return cached
    }
    struct Response: Decodable { let data: [Surah] }
    guard let res = try? await APIClient.shared.get("/quran/chapters", as: Response.self), !res.data.isEmpty else {
      return []
    }
    memoSurahs = res.data
    LocalStore.encode(res.data, for: surahsCacheKey)
    return res.data
  }

  static func verse(surahId: Int, verseNumber: Int) async -> Verse? {
    #if DEBUG
    if DebugLaunch.quran != nil { return QuranPreview.verses(surahID: surahId).first { $0.verse_number == verseNumber } }
    #endif
    struct Response: Decodable { let data: Verse? }
    guard let res = try? await APIClient.shared.get("/quran/verse/\(surahId)/\(verseNumber)", as: Response.self),
      let verse = res.data
    else { return nil }
    return await localize(surahId: surahId, [verse]).first ?? verse
  }

  static func randomVerse() async -> (verse: Verse, surah: Surah)? {
    let all = await surahs()
    guard let surah = all.randomElement(), surah.verse_count > 0 else { return nil }
    guard let verse = await verse(surahId: surah.id, verseNumber: Int.random(in: 1...surah.verse_count)) else {
      return nil
    }
    return (verse, surah)
  }

  /// Ayetlerin anlamını seçili dile çevirir (Türkçe'de dokunmaz). Anlam alınamazsa Türkçe meal kalır.
  static func localize(surahId: Int, _ verses: [Verse]) async -> [Verse] {
    let lang = Localizer.shared.language
    guard lang != .tr, let sourceName = foreignMeaningSource[lang] else { return verses }
    let map = await chapterMeaning(surahId: surahId, lang: lang)
    guard !map.isEmpty else { return verses }
    return verses.map { v in
      guard let text = map[v.verse_number] else { return v }
      var copy = v
      copy.translation.text = text
      copy.translation.author = .init(id: lang.rawValue, name: sourceName)
      return copy
    }
  }

  /// Bir surenin seçili dildeki ayet anlamları: ayet no → metin.
  static func chapterMeaning(surahId: Int, lang: AppLanguage) async -> [Int: String] {
    let key = "\(lang.rawValue)_\(surahId)"
    if let task = meaningTasks[key] { return await task.value }
    let task = Task { await fetchChapterMeaning(surahId: surahId, lang: lang) }
    meaningTasks[key] = task
    let result = await task.value
    if result.isEmpty { meaningTasks[key] = nil }
    return result
  }

  private static func fetchChapterMeaning(surahId: Int, lang: AppLanguage) async -> [Int: String] {
    guard !DebugLaunch.isIsolated else { return [:] }
    let cacheKey = "@salah_meaning_\(lang.rawValue)_\(surahId)"
    if let cached = LocalStore.decode([String: String].self, cacheKey) {
      return Dictionary(uniqueKeysWithValues: cached.compactMap { k, v in Int(k).map { ($0, v) } })
    }

    var map: [Int: String] = [:]
    if lang == .en {
      struct Response: Decodable {
        struct Item: Decodable { let text: String? }
        let translations: [Item]?
      }
      let url = URL(string: "https://api.quran.com/api/v4/quran/translations/20?chapter_number=\(surahId)")!
      if let (data, _) = try? await URLSession.shared.data(from: url),
        let res = try? JSONDecoder().decode(Response.self, from: data)
      {
        for (i, item) in (res.translations ?? []).enumerated() { map[i + 1] = stripHTML(item.text ?? "") }
      }
    } else {
      struct Response: Decodable {
        struct Item: Decodable {
          let verse_key: String?
          let text: String?
        }
        struct Pagination: Decodable { let next_page: Int? }
        let tafsirs: [Item]?
        let pagination: Pagination?
      }
      for page in 1..<20 {
        let url = URL(string: "https://api.quran.com/api/v4/tafsirs/16/by_chapter/\(surahId)?per_page=50&page=\(page)")!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
          let res = try? JSONDecoder().decode(Response.self, from: data)
        else { break }
        for item in res.tafsirs ?? [] {
          if let n = item.verse_key?.split(separator: ":").last.flatMap({ Int($0) }) {
            map[n] = stripHTML(item.text ?? "")
          }
        }
        if res.pagination?.next_page == nil { break }
      }
    }
    if !map.isEmpty {
      LocalStore.encode(Dictionary(uniqueKeysWithValues: map.map { (String($0.key), $0.value) }), for: cacheKey)
    }
    return map
  }

  static func stripHTML(_ html: String) -> String {
    html
      .replacingOccurrences(of: #"<sup[^>]*>[\s\S]*?</sup>"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

/// Sure adı seçili dilde: Türkçe okunuş (sunucudan), İngilizce okunuş ya da Arapça ad.
/// `withSuffix`: "Fâtiha Suresi" / "Surah Al-Fatihah". RN: src/i18n/surahs.ts
func surahName(_ surah: Surah, withSuffix: Bool = false) -> String {
  let lang = Localizer.shared.language
  if lang == .ar { return surah.name_arabic ?? surah.name }
  let name = lang == .en ? (SurahNamesEn.map[String(surah.id)] ?? surah.name) : surah.name
  return withSuffix ? t("quran.surahWithName", ["name": name]) : name
}

private enum SurahNamesEn {
  static let map: [String: String] = {
    guard let url = Bundle.main.url(forResource: "surahNamesEn", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return [:] }
    return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
  }()
}

/// Uthmani (Hafs) metin için paketteki KFGQPC fontu (cezm U+06E1 sistem fontunda görünmez).
enum QuranFont {
  static let name = "KFGQPCHAFSUthmanicScript-Regula"

  /// Ardışık tenvin (U+08F0–08F2) fontta yok; karşılığı olan düz tenvine eşlenir.
  static func text(_ s: String) -> String {
    String(
      String.UnicodeScalarView(
        s.unicodeScalars.map { scalar in
          (0x08F0...0x08F2).contains(scalar.value) ? Unicode.Scalar(scalar.value - 0x08F0 + 0x064B)! : scalar
        }))
  }
}

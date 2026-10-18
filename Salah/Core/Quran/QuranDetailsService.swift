import Foundation

struct TajweedSegment: Codable, Equatable, Sendable { var text: String; var rule: String? }
struct VerseTranslation: Codable, Equatable, Sendable {
  struct Footnote: Codable, Equatable, Identifiable, Sendable { var id: Int; var text: String; var number: Int }
  var authorId: String
  var authorName: String
  var text: String
  var footnotes: [Footnote]
}
struct VerseWord: Codable, Equatable, Sendable {
  var arabic: String
  var transliteration: String?
  var meaning: String?
}
struct MealAuthor: Identifiable {
  var id: String
  var name: String
  var short: String
}

enum TajweedParser {
  static func parse(_ html: String) -> [TajweedSegment] {
    let pattern = #"<(tajweed|span)\s+class=["']?([a-z_]+)["']?>([\s\S]*?)</\1>"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [.init(text: html, rule: nil)] }
    let ns = html as NSString
    var result: [TajweedSegment] = [], end = 0
    for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
      if match.range.location > end { result.append(.init(text: ns.substring(with: NSRange(location: end, length: match.range.location - end)), rule: nil)) }
      let tag = ns.substring(with: match.range(at: 1)), rule = ns.substring(with: match.range(at: 2))
      result.append(.init(text: ns.substring(with: match.range(at: 3)), rule: tag == "tajweed" || rule == "end" ? rule : nil))
      end = match.range.location + match.range.length
    }
    if end < ns.length { result.append(.init(text: ns.substring(from: end), rule: nil)) }
    return result
  }
}

extension QuranService {
  static let mealAuthors: [MealAuthor] = [
    .init(id: "diyanet", name: "Diyanet İşleri", short: "Diyanet"),
    .init(id: "diyanet-vakfi", name: "Diyanet Vakfı", short: "D. Vakfı"),
    .init(id: "elmalili", name: "Elmalılı Hamdi Yazır", short: "Elmalılı"),
    .init(id: "esed", name: "Muhammed Esed", short: "Esed"),
    .init(id: "ates", name: "Süleyman Ateş", short: "S. Ateş"),
    .init(id: "bulac", name: "Ali Bulaç", short: "A. Bulaç"),
  ]
  static var authors: [MealAuthor] {
    let lang = Localizer.shared.language
    if lang == .tr { return mealAuthors }
    let name = foreignMeaningSource[lang] ?? ""
    return [.init(id: lang.rawValue, name: name, short: name)]
  }

  static func surah(_ id: Int) async -> [Verse] {
    #if DEBUG
    if DebugLaunch.quran != nil { return QuranPreview.verses(surahID: id) }
    #endif
    let key = "QURAN_SURAH_CACHE_v2_\(id)"
    if let cached = LocalStore.decode([Verse].self, key), !cached.isEmpty {
      return await localize(surahId: id, cached)
    }
    struct Response: Decodable {
      struct Body: Decodable { var verses: [Verse] }
      var data: Body
    }
    guard let response = try? await APIClient.shared.get("/quran/surah/\(id)", as: Response.self), !response.data.verses.isEmpty else { return [] }
    LocalStore.encode(response.data.verses, for: key)
    return await localize(surahId: id, response.data.verses)
  }

  static func tajweed(_ id: Int) async -> [Int: [TajweedSegment]] {
    let key = "@salah_tajweed_\(id)"
    if let cached = LocalStore.decode([String: [TajweedSegment]].self, key) {
      return Dictionary(uniqueKeysWithValues: cached.compactMap { k, v in Int(k).map { ($0, v) } })
    }
    guard !DebugLaunch.isIsolated else { return [:] }
    struct Response: Decodable {
      struct Item: Decodable { var verse_key: String; var text_uthmani_tajweed: String }
      var verses: [Item]
    }
    let url = URL(string: "https://api.quran.com/api/v4/quran/verses/uthmani_tajweed?chapter_number=\(id)")!
    guard let result = try? await external(url, as: Response.self) else { return [:] }
    var map: [Int: [TajweedSegment]] = [:]
    for item in result.verses {
      if let n = Int(item.verse_key.split(separator: ":").last ?? "") { map[n] = TajweedParser.parse(item.text_uthmani_tajweed) }
    }
    LocalStore.encode(Dictionary(uniqueKeysWithValues: map.map { (String($0.key), $0.value) }), for: key)
    return map
  }

  static func translation(surah: Int, verse: Int, author: String) async -> VerseTranslation? {
    #if DEBUG
    if DebugLaunch.quran != nil, let v = QuranPreview.verses(surahID: surah).first(where: { $0.verse_number == verse }) {
      return .init(authorId: author, authorName: v.translation.author?.name ?? "", text: v.translation.text, footnotes: [])
    }
    #endif
    if let lang = AppLanguage(rawValue: author), lang != .tr {
      let map = await chapterMeaning(surahId: surah, lang: lang)
      return map[verse].map { .init(authorId: author, authorName: foreignMeaningSource[lang] ?? "", text: $0, footnotes: []) }
    }
    guard mealAuthors.contains(where: { $0.id == author }) else { return nil }
    let key = "@salah_meal_v2_\(surah)_\(verse)_\(author)"
    if let cached = LocalStore.decode(VerseTranslation.self, key) { return cached }
    struct Response: Decodable { var data: Verse? }
    guard let response = try? await APIClient.shared.get("/quran/verse/\(surah)/\(verse)?meal=\(author)", as: Response.self), let t = response.data?.translation else { return nil }
    let result = VerseTranslation(authorId: author, authorName: t.author?.name ?? "", text: t.text, footnotes: [])
    LocalStore.encode(result, for: key)
    return result
  }

  static func words(surah: Int, verse: Int) async -> [VerseWord] {
    let key = "@salah_words_\(surah)_\(verse)"
    if let cached = LocalStore.decode([VerseWord].self, key) { return cached }
    guard !DebugLaunch.isIsolated else { return [] }
    struct Response: Decodable {
      struct Body: Decodable { var words: [Word] }
      struct Word: Decodable {
        struct Text: Decodable { var text: String? }
        var char_type_name: String
        var text_uthmani: String?
        var transliteration: Text?
        var translation: Text?
      }
      var verse: Body
    }
    let url = URL(string: "https://api.quran.com/api/v4/verses/by_key/\(surah):\(verse)?words=true&word_fields=text_uthmani,transliteration")!
    guard let result = try? await external(url, as: Response.self) else { return [] }
    let words = result.verse.words.filter { $0.char_type_name == "word" }.map {
      VerseWord(arabic: $0.text_uthmani ?? "", transliteration: $0.transliteration?.text, meaning: $0.translation?.text)
    }
    if !words.isEmpty { LocalStore.encode(words, for: key) }
    return words
  }

  private static func external<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    return try JSONDecoder().decode(type, from: data)
  }
}

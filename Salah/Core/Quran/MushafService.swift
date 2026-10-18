import Foundation

struct MushafWord: Codable, Equatable, Sendable {
  var text: String
  var isEnd: Bool
  var verse: String
}
/// Açık kind alanı RN cache JSON'uyla aynı kalır (Swift enum etiketlemesi kullanılmaz).
struct MushafLine: Codable, Equatable, Sendable {
  var kind: String
  var words: [MushafWord]?
  var surahId: Int?
}
struct MushafPage: Codable, Equatable, Sendable {
  var page: Int
  var lines: [MushafLine]
  var centered: Bool
  var surahId: Int
  var juz: Int
}
struct MushafAPIVerse: Codable, Sendable {
  struct Word: Codable, Sendable {
    var char_type_name: String
    var line_number: Int
    var text_qpc_hafs: String
  }
  var verse_key: String
  var verse_number: Int
  var juz_number: Int
  var words: [Word]
  var surahID: Int { Int(verse_key.split(separator: ":").first ?? "") ?? 0 }
}

enum MushafLayout {
  static let pageCount = 604
  enum Failure: Error { case invalidPage, empty, invalidLines }

  /// RN buildMushafPage ile aynı 15 satır ve başlık/besmele kuralları.
  static func build(page: Int, verses: [MushafAPIVerse]) throws -> MushafPage {
    guard (1...pageCount).contains(page) else { throw Failure.invalidPage }
    guard let first = verses.first else { throw Failure.empty }
    var lines: [Int: [MushafWord]] = [:], firstVerse: [Int: MushafAPIVerse] = [:]
    for verse in verses {
      guard (1...114).contains(verse.surahID) else { throw Failure.invalidLines }
      for word in verse.words {
        guard (1...15).contains(word.line_number) else { throw Failure.invalidLines }
        if firstVerse[word.line_number] == nil { firstVerse[word.line_number] = verse }
        lines[word.line_number, default: []].append(.init(text: word.text_qpc_hafs, isEnd: word.char_type_name == "end", verse: verse.verse_key))
      }
    }
    guard !lines.isEmpty else { throw Failure.empty }
    if page <= 2 {
      var result = [MushafLine(kind: "header", surahId: first.surahID)]
      if page == 2 { result.append(.init(kind: "basmala")) }
      result += lines.keys.sorted().map { .init(kind: "text", words: lines[$0]) }
      return .init(page: page, lines: result, centered: true, surahId: first.surahID, juz: first.juz_number)
    }
    var result: [MushafLine?] = (1...15).map { n in lines[n].map { .init(kind: "text", words: $0) } }
    var i = 0
    while i < 15 {
      if result[i] != nil { i += 1; continue }
      var j = i
      while j < 15 && result[j] == nil { j += 1 }
      let next = j < 15 ? firstVerse[j + 1] : nil
      let surah = next?.surahID ?? ((verses.last?.surahID ?? first.surahID) + 1)
      if j - i == 1 && i == 0 && next != nil && surah != 9 { result[i] = .init(kind: "basmala") }
      else {
        result[i] = .init(kind: "header", surahId: surah)
        if j - i >= 2 && surah != 9 { result[i + 1] = .init(kind: "basmala") }
      }
      i = j
    }
    return .init(page: page, lines: result.compactMap { $0 }, centered: false, surahId: first.surahID, juz: first.juz_number)
  }
}

/// Tekrarlanan sayfa istekleri birleştirilir, cache biçimi RN ile ortaktır.
enum MushafService {
  private static var memory: [Int: MushafPage] = [:]
  private static var inflight: [Int: Task<MushafPage, Error>] = [:]

  static func page(_ number: Int) async throws -> MushafPage {
    guard (1...604).contains(number) else { throw MushafLayout.Failure.invalidPage }
    if let page = memory[number] { return page }
    let key = "@salah_mushaf_page_v2_\(number)"
    if let cached = LocalStore.decode(MushafPage.self, key), valid(cached, number: number) {
      memory[number] = cached
      return cached
    }
    if let task = inflight[number] { return try await task.value }
    let task = Task<MushafPage, Error> {
      #if DEBUG
      if DebugLaunch.quran != nil, let verses = QuranPreview.mushafVerses[number] {
        return try MushafLayout.build(page: number, verses: verses)
      }
      #endif
      guard !DebugLaunch.isIsolated else { throw URLError(.notConnectedToInternet) }
      let url = URL(string: "https://api.quran.com/api/v4/verses/by_page/\(number)?words=true&word_fields=text_qpc_hafs,line_number&per_page=50&mushaf=5&fields=juz_number")!
      var request = URLRequest(url: url)
      request.timeoutInterval = 20
      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
      struct Response: Decodable { var verses: [MushafAPIVerse] }
      let verses = try JSONDecoder().decode(Response.self, from: data).verses
      return try MushafLayout.build(page: number, verses: verses)
    }
    inflight[number] = task
    defer { inflight[number] = nil }
    let result = try await task.value
    // Kitabın tüm sayfalarını bellekte tutma; cihaz cache'i zaten kalıcı.
    if memory.count >= 12 { memory.removeAll() }
    memory[number] = result
    if !DebugLaunch.isIsolated { LocalStore.encode(result, for: key) }
    return result
  }

  static func prefetch(_ number: Int) {
    guard !DebugLaunch.isIsolated else { return }
    for n in [number - 1, number + 1, number + 2] where (1...604).contains(n) {
      Task { _ = try? await page(n) }
    }
  }
  private static func valid(_ page: MushafPage, number: Int) -> Bool {
    page.page == number && !page.lines.isEmpty && page.lines.count <= 15 && (1...114).contains(page.surahId)
      && page.lines.allSatisfy { ["text", "header", "basmala"].contains($0.kind) && ($0.kind != "text" || !($0.words ?? []).isEmpty) }
  }
}

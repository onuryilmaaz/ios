import Foundation

nonisolated struct MushafWord: Codable, Equatable, Sendable {
  var text: String
  var isEnd: Bool
  var verse: String
  /// Medine mushafı hattının (QCF V2/V4) sayfa yazı tipindeki karşılığı.
  var code: String?
  /// Kelime meali (sayfanın indirildiği dilde), okunuşu ve ses yolu (`audio.qurancdn.com/` altında).
  var meaning: String?
  var translit: String?
  var audio: String?
}
nonisolated struct MushafLine: Codable, Equatable, Sendable {
  var kind: String
  var words: [MushafWord]?
  var surahId: Int?
}
nonisolated struct MushafPage: Codable, Equatable, Sendable {
  var page: Int
  var lines: [MushafLine]
  var centered: Bool
  var surahId: Int
  var juz: Int
}
nonisolated struct MushafAPIVerse: Codable, Sendable {
  struct Word: Codable, Sendable {
    struct Text: Codable, Sendable { var text: String? }
    var char_type_name: String
    var line_number: Int
    var text_qpc_hafs: String
    var code_v2: String?
    var audio_url: String?
    var translation: Text?
    var transliteration: Text?
  }
  var verse_key: String
  var verse_number: Int
  var juz_number: Int
  var words: [Word]
  var surahID: Int { Int(verse_key.split(separator: ":").first ?? "") ?? 0 }
}

nonisolated enum MushafLayout {
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
        let isEnd = word.char_type_name == "end"
        lines[word.line_number, default: []].append(.init(
          text: word.text_qpc_hafs, isEnd: isEnd, verse: verse.verse_key, code: word.code_v2,
          meaning: isEnd ? nil : word.translation?.text, translit: isEnd ? nil : word.transliteration?.text,
          audio: isEnd ? nil : word.audio_url))
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

/// Mushaf sayfaları. Tekrarlanan istekler birleştirilir; sayfa (kelime mealiyle) dile göre dosyaya yazılır:
/// `Application Support/Mushaf/pages-v3/<dil>/<sayfa>.json` (iCloud yedeğine girmez). Eski sürüm sayfaları
/// ayarlar deposundaydı (`@salah_mushaf_page_v2_*`); bir kez silinir.
enum MushafService {
  private static var memory: [String: MushafPage] = [:]
  private static var inflight: [String: Task<MushafPage, Error>] = [:]

  /// Kelime meali dili: Arapça arayüzde meal gösterilmez, veri İngilizce iner.
  static var language: String { Localizer.shared.language == .tr ? "tr" : "en" }
  static var showsMeanings: Bool { Localizer.shared.language != .ar }

  nonisolated static var root: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Mushaf", isDirectory: true)
  }
  nonisolated static func pageFile(_ number: Int, language: String) -> URL {
    root.appendingPathComponent("pages-v3/\(language)/\(number).json")
  }

  static func page(_ number: Int) async throws -> MushafPage {
    guard (1...604).contains(number) else { throw MushafLayout.Failure.invalidPage }
    let lang = language
    let key = "\(lang)/\(number)"
    if let page = memory[key] { return page }
    if let cached = readFile(number, language: lang) {
      remember(key, cached)
      return cached
    }
    if let task = inflight[key] { return try await task.value }
    let task = Task<MushafPage, Error> {
      #if DEBUG
      if DebugLaunch.quran != nil, DebugLaunch.quran != "mushafLive", let verses = QuranPreview.mushafVerses[number] {
        return try MushafLayout.build(page: number, verses: verses)
      }
      #endif
      guard !DebugLaunch.isIsolated else { throw URLError(.notConnectedToInternet) }
      return try await fetch(number, language: lang)
    }
    inflight[key] = task
    defer { inflight[key] = nil }
    let result = try await task.value
    remember(key, result)
    if !DebugLaunch.isIsolated { write(result, language: lang) }
    return result
  }

  /// Ağdan bir sayfa (İndirilenler'deki toplu indirme de kullanır).
  nonisolated static func fetch(_ number: Int, language: String) async throws -> MushafPage {
    let url = URL(string: "https://api.quran.com/api/v4/verses/by_page/\(number)?words=true&word_fields=text_qpc_hafs,line_number,code_v2&per_page=50&mushaf=5&fields=juz_number&language=\(language)")!
    var request = URLRequest(url: url)
    request.timeoutInterval = 20
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    struct Response: Decodable { var verses: [MushafAPIVerse] }
    let verses = try JSONDecoder().decode(Response.self, from: data).verses
    return try MushafLayout.build(page: number, verses: verses)
  }

  nonisolated static func hasFile(_ number: Int, language: String) -> Bool {
    FileManager.default.fileExists(atPath: pageFile(number, language: language).path)
  }

  nonisolated static func write(_ page: MushafPage, language: String) {
    let file = pageFile(page.page, language: language)
    let dir = file.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var folder = dir
      try? folder.setResourceValues(values)
    }
    if let data = try? JSONEncoder().encode(page) { try? data.write(to: file, options: .atomic) }
  }

  private static func readFile(_ number: Int, language: String) -> MushafPage? {
    guard let data = try? Data(contentsOf: pageFile(number, language: language)),
      let page = try? JSONDecoder().decode(MushafPage.self, from: data), valid(page, number: number)
    else { return nil }
    return page
  }

  private static func remember(_ key: String, _ page: MushafPage) {
    // Kitabın tüm sayfalarını bellekte tutma; dosya önbelleği zaten kalıcı.
    if memory.count >= 12 { memory.removeAll() }
    memory[key] = page
  }

  static func prefetch(_ number: Int) {
    guard !DebugLaunch.isIsolated else { return }
    for n in [number - 1, number + 1, number + 2] where (1...604).contains(n) {
      Task { _ = try? await page(n) }
    }
  }

  /// Ayarlar deposundaki eski sayfa önbelleğini bir kez temizler.
  static func dropLegacyCache() {
    guard LocalStore.string("@salah_mushaf_legacy_dropped") == nil else { return }
    for n in 1...604 { LocalStore.remove("@salah_mushaf_page_v2_\(n)") }
    LocalStore.set("1", for: "@salah_mushaf_legacy_dropped")
  }

  static func valid(_ page: MushafPage, number: Int) -> Bool {
    page.page == number && !page.lines.isEmpty && page.lines.count <= 15 && (1...114).contains(page.surahId)
      && page.lines.allSatisfy { ["text", "header", "basmala"].contains($0.kind) && ($0.kind != "text" || !($0.words ?? []).isEmpty) }
  }
}

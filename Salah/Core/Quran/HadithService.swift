import Foundation
import SQLite3

/// Gömülü hadis veritabanı (mobile/assets/data/hadiths_v2.db, RN ile aynı dosya).
/// Paket içinden salt okunur açılır; kopyalamaya gerek yok.
///
/// Numaralama fawazahmed0/hadith-api'nin Türkçe baskısıyla aynı; İngilizce/Arapça
/// arayüzde aynı hadisin o dildeki metni oradan çekilir. Ağ yoksa Türkçe metne düşülür.
/// RN: services/hadith.service.ts
enum HadithService {
  struct Result: Sendable {
    let number: Int
    let text: String
    let bookName: String
  }

  nonisolated(unsafe) private static var db: OpaquePointer?

  private static func open() -> OpaquePointer? {
    if let db { return db }
    guard let path = Bundle.main.path(forResource: "hadiths_v2", ofType: "db") else { return nil }
    var handle: OpaquePointer?
    guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
      sqlite3_close(handle)
      return nil
    }
    db = handle
    return handle
  }

  static func random(book: String? = nil) async -> Result? {
    guard let db = open() else { return nil }
    var sql = "SELECT book, hadith_number, text FROM hadiths "
    if book != nil { sql += "WHERE book = ? " }
    sql += "ORDER BY RANDOM() LIMIT 1"

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(stmt) }
    if let book { sqlite3_bind_text(stmt, 1, book, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    guard sqlite3_step(stmt) == SQLITE_ROW,
      let bookC = sqlite3_column_text(stmt, 0),
      let textC = sqlite3_column_text(stmt, 2)
    else { return nil }

    let rowBook = String(cString: bookC)
    let number = Int(sqlite3_column_int(stmt, 1))
    let original = String(cString: textC)
    let translated = await translatedText(book: rowBook, number: number)
    return Result(
      number: number,
      // Kaynak eserdeki dipnot/tahric aparatı ilham kartında gürültü.
      text: translated ?? cleanNarrationText(original),
      bookName: bookDisplayName(rowBook)
    )
  }

  private static func translatedText(book: String, number: Int) async -> String? {
    let prefix: String
    switch Localizer.shared.language {
    case .en: prefix = "eng"
    case .ar: prefix = "ara"
    case .tr: return nil
    }
    let url = URL(string: "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/\(prefix)-\(book)/\(number).json")!
    var request = URLRequest(url: url)
    request.timeoutInterval = 6
    struct Response: Decodable {
      struct Item: Decodable { let text: String? }
      let hadiths: [Item]?
    }
    guard let (data, response) = try? await URLSession.shared.data(for: request),
      (response as? HTTPURLResponse)?.statusCode == 200,
      let res = try? JSONDecoder().decode(Response.self, from: data),
      let raw = res.hadiths?.first?.text
    else { return nil }
    let text = raw
      .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
  }

  static func bookDisplayName(_ book: String) -> String {
    let names: [AppLanguage: [String: String]] = [
      .tr: ["bukhari": "Sahih-i Buhârî", "muslim": "Sahih-i Müslim", "abudawud": "Sünen-i Ebû Dâvûd", "tirmidhi": "Sünen-i Tirmizî"],
      .en: ["bukhari": "Sahih al-Bukhari", "muslim": "Sahih Muslim", "abudawud": "Sunan Abi Dawud", "tirmidhi": "Jami' at-Tirmidhi"],
      .ar: ["bukhari": "صحيح البخاري", "muslim": "صحيح مسلم", "abudawud": "سنن أبي داود", "tirmidhi": "جامع الترمذي"],
    ]
    return names[Localizer.shared.language]?[book] ?? book
  }
}

/// Hadis metnindeki ilmî aparatı (dipnot numaraları, tahric kaynakçası) temizler.
/// RN: utils/scriptureText.ts, aynı kalıplar ve aynı istisnalar
/// (`{açıklama}` ve `(1) … (2)` sıralamalarına dokunulmaz).
func cleanNarrationText(_ input: String?) -> String {
  guard let input, !input.isEmpty else { return "" }
  func re(_ s: String, _ pattern: String, _ with: String, caseInsensitive: Bool = false) -> String {
    var options: String.CompareOptions = [.regularExpression]
    if caseInsensitive { options.insert(.caseInsensitive) }
    return s.replacingOccurrences(of: pattern, with: with, options: options)
  }
  var s = input
  // Metnin sonundaki tahric bloğu: "Diğer tahric:", "Diğer Tahric edenler:", "Diğer tahric;"
  s = re(s, #"\s*(?:diğer\s+)?tahric(?:\s+edenler)?\s*[:;][\s\S]*$"#, "", caseInsensitive: true)
  // "Tekrar: 54, 2529." — yalnız ardından sayı listesi gelirse.
  s = re(s, #"\s*Tekrar[ıi]?\s*:\s*\d[\d\s,.\-–]*"#, " ", caseInsensitive: true)
  s = re(s, #"\[\s*\d+\s*\]"#, "")
  s = re(s, #"\{\s*[.…]+\s*\}"#, "…")
  s = re(s, #"[ \t]{2,}"#, " ")
  s = re(s, #"\s+([,.;:!?])"#, "$1")
  s = re(s, #"\s*\n\s*"#, "\n")
  s = s.trimmingCharacters(in: .whitespacesAndNewlines)
  return re(s, #"[\s,;:]+$"#, "")
}

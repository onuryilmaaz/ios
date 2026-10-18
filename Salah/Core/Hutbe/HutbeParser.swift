import Foundation

/// Diyanet Cuma hutbesi ayrıştırıcıları (saf). RN: modules/hutbe/hutbe.parse.ts (aynı kurallar,
/// aynı fixture testleri).
///
/// Liste: Diyanet'in hutbe sayfası (SharePoint) hutbeleri `var WPQ1ListData = {...};` JSON'u ya da
/// (tarayıcı olmayan isteklerde) düz HTML tablosu olarak verir.
/// Metin: PDF'ten sütun sırasıyla çıkarılan satırlar. Arapça başlık bloğu atılır; hitap satırları
/// ("Aziz Müminler!") bölüm başlığı olur, sondaki numaralı satırlar dipnottur.
nonisolated enum HutbeParser {
  static let base = "https://dinhizmetleri.diyanet.gov.tr"

  struct Item: Codable, Equatable, Identifiable, Sendable {
    let id: String
    /// Yerel gece yarısı (ms; RN önbellek biçimiyle aynı).
    let dateMs: Double
    let title: String
    let pdfUrl: String?
    let audioUrl: String?

    var date: Date { Date(timeIntervalSince1970: dateMs / 1000) }
  }

  struct Section: Codable, Equatable, Sendable {
    /// "Aziz Müminler!" gibi hitap; ilk bölümde olmayabilir.
    let heading: String?
    let text: String
  }

  struct Parsed: Codable, Equatable, Sendable {
    let sections: [Section]
    let footnotes: [String]
  }

  // MARK: - Liste

  /// Hutbe sayfasının HTML'inden liste (yeniden eskiye).
  static func list(_ html: String) -> [Item] {
    var rows: [[String: Any]] = []
    if let m = firstMatch(#"var WPQ\d+ListData = (\{[\s\S]*?\});"#, html),
      let data = m[1].data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      rows = json["Row"] as? [[String: Any]] ?? []
    }
    if rows.isEmpty { rows = rowsFromTable(html) }
    return rows.compactMap { r -> Item? in
      let id = (r["ID"] as? String) ?? (r["UniqueId"] as? String) ?? ""
      let title = ((r["Title"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard !id.isEmpty, !title.isEmpty, let date = parseDate(r["Tarih"] as? String) else { return nil }
      return Item(id: id, dateMs: date, title: title, pdfUrl: absoluteURL(r["PDF"] as? String), audioUrl: absoluteURL(r["Ses"] as? String))
    }
    .sorted { $0.dateMs > $1.dateMs }
  }

  /// JSON'suz sürüm: tarih hücresi (<nobr>2.10.2026</nobr>) taşıyan her <tr> bir hutbedir.
  private static func rowsFromTable(_ html: String) -> [[String: Any]] {
    var rows: [[String: Any]] = []
    for tr in allMatches(#"<tr([^>]*)>([\s\S]*?)</tr>"#, html) {
      let body = tr[2]
      guard let date = firstMatch(#"<nobr>\s*(\d{1,2}\.\d{1,2}\.\d{4})\s*</nobr>"#, body)?[1] else { continue }
      let cells = allMatches(#"<td[^>]*class="ms-vb2"[^>]*>([\s\S]*?)</td>"#, body).map {
        decodeEntities($0[1].replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression))
          .trimmingCharacters(in: .whitespacesAndNewlines)
      }
      func href(_ ext: String) -> String? { firstMatch(#"href="([^"]+\.\#(ext))""#, body, caseInsensitive: true)?[1] }
      let title = cells.count > 1 ? cells[1] : ""
      rows.append([
        "ID": firstMatch(#"\biid="\d+,(\d+),\d+""#, tr[1])?[1] ?? "\(date)-\(title)",
        "Tarih": date,
        "Title": title,
        "PDF": href("pdf") as Any,
        "Ses": href("mp3") as Any,
      ])
    }
    return rows
  }

  /// Yollar karışık geliyor (tam kodlu, ham Arapça ya da yarı kodlu): çözüp baştan kodla.
  /// RN: `encodeURI(decodeURI(path))`.
  static func absoluteURL(_ path: String?) -> String? {
    guard let path, !path.isEmpty else { return nil }
    let decoded = path.removingPercentEncoding ?? path
    let encoded = decoded.addingPercentEncoding(withAllowedCharacters: encodeURIAllowed) ?? decoded
    return encoded.hasPrefix("http") ? encoded : base + encoded
  }

  /// JS `encodeURI` tarafından kodlanmayan karakterler.
  private static let encodeURIAllowed = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789;,/?:@&=+$-_.!~*'()#")

  /// "2.10.2026" / "02.10.2026" → yerel gece yarısı (ms).
  static func parseDate(_ s: String?) -> Double? {
    guard let s, let m = firstMatch(#"^(\d{1,2})\.(\d{1,2})\.(\d{4})$"#, s.trimmingCharacters(in: .whitespaces)),
      let day = Int(m[1]), let month = Int(m[2]), let year = Int(m[3]),
      let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    else { return nil }
    return date.timeIntervalSince1970 * 1000
  }

  private static func decodeEntities(_ s: String) -> String {
    var out = s
    for m in allMatches(#"&#(\d+);"#, out).reversed() {
      if let n = UInt32(m[1]), let scalar = Unicode.Scalar(n) { out = out.replacingOccurrences(of: m[0], with: String(Character(scalar))) }
    }
    for m in allMatches(#"&#x([0-9a-fA-F]+);"#, out).reversed() {
      if let n = UInt32(m[1], radix: 16), let scalar = Unicode.Scalar(n) { out = out.replacingOccurrences(of: m[0], with: String(Character(scalar))) }
    }
    return out
      .replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&#39;", with: "'")
      .replacingOccurrences(of: "&apos;", with: "'")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
      .replacingOccurrences(of: "&nbsp;", with: " ")
      .replacingOccurrences(of: "&amp;", with: "&")
  }

  // MARK: - Metin

  static func text(_ raw: String) -> Parsed {
    let lines = raw.components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { l in
        !l.isEmpty && !matches(#"[\x{0600}-\x{06FF}\x{0750}-\x{077F}\x{FB50}-\x{FDFF}\x{FE70}-\x{FEFF}]"#, l)
          && !matches(#"^(tarih|date)\s*:"#, l, caseInsensitive: true)
          && !matches(#"^[\s.:…،؛-]+$"#, l)
          && !matches(#"(genel müdürlüğü|general directorate)"#, l, caseInsensitive: true)
          && !isTitle(l)
      }

    // Dipnotlar sondadır ve 1'den başlar: son "1 ..." satırından itibaren.
    let footStart = lines.lastIndex { firstMatch(#"^(\d{1,2})\s+\S"#, $0)?[1] == "1" }
    let body = footStart.map { Array(lines[..<$0]) } ?? lines
    let footLines = footStart.map { Array(lines[$0...]) } ?? []

    var footnotes: [String] = []
    for l in footLines {
      if matches(#"^(\d{1,2})\s+\S"#, l) || footnotes.isEmpty { footnotes.append(l) } else { footnotes[footnotes.count - 1] += " \(l)" }
    }

    var sections: [Section] = []
    var heading: String?
    var buffer: [String] = []
    func flush() {
      let text = stripFootnoteRefs(joinLines(buffer))
      if !text.isEmpty { sections.append(Section(heading: heading, text: text)) }
      buffer = []
    }
    for l in body {
      if isHeading(l) {
        flush()
        heading = l
      } else {
        buffer.append(l)
      }
    }
    flush()
    return Parsed(sections: sections, footnotes: footnotes)
  }

  private static func isHeading(_ line: String) -> Bool {
    line.hasSuffix("!") && line.utf16.count <= 40 && line.split(whereSeparator: \.isWhitespace).count <= 4
  }

  private static func isTitle(_ line: String) -> Bool {
    let tr = Locale(identifier: "tr_TR")
    let letters = line.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
    return letters > 3 && !line.hasSuffix("!") && line == line.uppercased(with: tr) && line != line.lowercased(with: tr)
  }

  /// "well-\nbeing": tireyi koru, boşluk koyma.
  private static func joinLines(_ lines: [String]) -> String {
    var out = ""
    for line in lines {
      if out.isEmpty {
        out = line
      } else if matches(#"\p{L}-$"#, out) {
        out += line
      } else {
        out += " \(line)"
      }
    }
    return out
  }

  /// Metin içi dipnot numaralarını atar: "fermanı…”1" → "fermanı…”".
  private static func stripFootnoteRefs(_ text: String) -> String {
    text
      .replacingOccurrences(of: #"([\p{L}.,;:!?…”’")])\d{1,2}(?=[\s,.;:!?”’"]|$)"#, with: "$1", options: .regularExpression)
      .replacingOccurrences(of: #"\s\d{1,2}(?=[”"])"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Regex yardımcıları

  private static func regex(_ pattern: String, caseInsensitive: Bool) -> NSRegularExpression? {
    try? NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
  }

  private static func matches(_ pattern: String, _ text: String, caseInsensitive: Bool = false) -> Bool {
    regex(pattern, caseInsensitive: caseInsensitive)?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
  }

  private static func groups(_ m: NSTextCheckingResult, _ text: String) -> [String] {
    (0..<m.numberOfRanges).map { i in
      Range(m.range(at: i), in: text).map { String(text[$0]) } ?? ""
    }
  }

  private static func firstMatch(_ pattern: String, _ text: String, caseInsensitive: Bool = false) -> [String]? {
    guard let re = regex(pattern, caseInsensitive: caseInsensitive),
      let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    else { return nil }
    return groups(m, text)
  }

  private static func allMatches(_ pattern: String, _ text: String) -> [[String]] {
    guard let re = regex(pattern, caseInsensitive: false) else { return [] }
    return re.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { groups($0, text) }
  }
}

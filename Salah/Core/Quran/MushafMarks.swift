import Foundation

/// Mushaf kenar işaretleri: cüz, hizb ve çeyrek (rub) başları ile secde ayetleri.
/// Veri `mushaf-marks.generated.json` (ios/scripts/gen-mushaf-marks.py; Medine Mushafı, api.quran.com).
nonisolated enum MushafMarks {
  enum Kind: Equatable, Sendable {
    case juz(Int)
    case hizb(Int)
    /// Hizbin 1., 2. ya da 3. çeyreği (¼, ½, ¾).
    case quarter(hizb: Int, part: Int)
    case sajdah

    /// Basılı Mushaf'taki kenar notu. Mushaf'ın kendi yazısının parçası olduğundan uygulama dilinden bağımsız Arapçadır;
    /// ekran okuyucu `a11yLabel` ile seçili dilde okur.
    var printed: String {
      switch self {
      case .juz(let number): "۞ الجزء \(MushafMarks.arabicDigits(number))"
      case .hizb(let number): "۞ الحزب \(MushafMarks.arabicDigits(number))"
      case .quarter(let hizb, let part): "۞ \(["", "ربع", "نصف", "ثلاثة أرباع"][part]) الحزب \(MushafMarks.arabicDigits(hizb))"
      case .sajdah: "سجدة ۩"
      }
    }

    @MainActor var a11yLabel: String {
      switch self {
      case .juz(let number): t("mushaf.marks.juz", ["number": number])
      case .hizb(let number): t("mushaf.marks.hizb", ["number": number])
      case .quarter(let hizb, let part): t("mushaf.marks.quarter", ["number": hizb, "part": part])
      case .sajdah: t("mushaf.marks.sajdah")
      }
    }
  }

  private struct File: Decodable {
    let rub: [String]
    let sajdah: [String]
  }

  /// Ayet anahtarı → çeyreğin sırası (1...240).
  private static let rubStarts: [String: Int] = {
    Dictionary(uniqueKeysWithValues: (file?.rub ?? []).enumerated().map { ($1, $0 + 1) })
  }()
  private static let sajdahs: Set<String> = Set(file?.sajdah ?? [])
  private static let file: File? = {
    guard let url = Bundle.main.url(forResource: "mushaf-marks.generated", withExtension: "json"),
      let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(File.self, from: data)
  }()

  /// 18 → "١٨"
  static func arabicDigits(_ number: Int) -> String {
    String(String(number).unicodeScalars.map { Character(UnicodeScalar(0x0660 + Int($0.value) - 48)!) })
  }

  /// Çeyreğin sırasından işaret: her 8 çeyrek bir cüz, her 4 çeyrek bir hizb.
  static func kind(rub: Int) -> Kind {
    let index = rub - 1
    if index % 8 == 0 { return .juz(index / 8 + 1) }
    if index % 4 == 0 { return .hizb(index / 4 + 1) }
    return .quarter(hizb: index / 4 + 1, part: index % 4)
  }

  /// Sayfadaki işaretler, satır sırasına göre: çeyrek, ayetin ilk kelimesinin satırında; secde, ayet sonunun satırında.
  /// İlk iki (ortalanmış) sayfada işaret yok.
  static func marks(for page: MushafPage) -> [Int: Kind] {
    guard !page.centered else { return [:] }
    var out: [Int: Kind] = [:]
    var seen: Set<String> = []
    for (index, line) in page.lines.enumerated() {
      for word in line.words ?? [] {
        if !seen.contains(word.verse) {
          seen.insert(word.verse)
          if let rub = rubStarts[word.verse], out[index] == nil { out[index] = kind(rub: rub) }
        }
        if word.isEnd, sajdahs.contains(word.verse) { out[index] = .sajdah }
      }
    }
    return out
  }
}

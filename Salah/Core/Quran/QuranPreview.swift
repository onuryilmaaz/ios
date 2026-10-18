import Foundation

#if DEBUG
/// Yalnız izole Debug önizlemeleri: açık veri CDN'i ve RN'nin gerçek Mushaf fixture'ı.
/// Uydurma ayet/metin veya test için canlı backend isteği kullanılmaz.
enum QuranPreview {
  private struct File: Decodable { var surahs: [Surah]; var verses: [Verse]; var english: [String: String]; var englishAuthor: String? }
  private static let data: File? = {
    guard let url = Bundle.main.url(forResource: "QuranPreview", withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(File.self, from: data)
  }()
  static var surahs: [Surah] { data?.surahs ?? [] }
  static func verses(surahID: Int) -> [Verse] {
    guard surahID == 1 else { return [] }
    return (data?.verses ?? []).map { original in
      var verse = original
      if Localizer.shared.language == .en, let text = data?.english[String(verse.verse_number)] {
        verse.translation.text = text
        verse.translation.author = .init(id: "en", name: data?.englishAuthor ?? QuranService.foreignMeaningSource[.en]!)
      }
      return verse
    }
  }
  static let mushafVerses: [Int: [MushafAPIVerse]] = {
    guard let url = Bundle.main.url(forResource: "mushaf-pages", withExtension: "json"), let data = try? Data(contentsOf: url),
      let file = try? JSONDecoder().decode([String: [MushafAPIVerse]].self, from: data) else { return [:] }
    return Dictionary(uniqueKeysWithValues: file.compactMap { k, v in Int(k).map { ($0, v) } })
  }()
  static func words(verse: Int) -> [VerseWord] {
    (mushafVerses[1]?.first { $0.verse_number == verse }?.words ?? []).filter { $0.char_type_name == "word" }
      .map { .init(arabic: $0.text_qpc_hafs, transliteration: nil, meaning: nil) }
  }
}
#endif

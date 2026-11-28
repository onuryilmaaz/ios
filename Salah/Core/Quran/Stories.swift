import Foundation

/// Kıssanın bir bölümü: sure ve ayet aralığı, başlık dil koduna göre.
struct StorySection: Decodable, Hashable {
  let s: Int
  let from: Int
  let to: Int
  let title: [String: String]

  var text: String { StoryText.pick(title) }
}

struct Story: Decodable, Identifiable {
  let id: String
  let name: [String: String]
  let summary: [String: String]
  let sections: [StorySection]

  var title: String { StoryText.pick(name) }
  var overview: String { StoryText.pick(summary) }
}

enum StoryText {
  /// Seçili dil, yoksa İngilizce, o da yoksa Türkçe.
  static func pick(_ map: [String: String]) -> String {
    let lang = Localizer.shared.language.rawValue
    return map[lang] ?? map["en"] ?? map["tr"] ?? ""
  }
}

/// `Resources/stories.json`: kıssalar, ad/özet/başlıklar çok dilli.
enum StoryCatalog {
  static let all: [Story] = {
    guard let url = Bundle.main.url(forResource: "stories", withExtension: "json"), let data = try? Data(contentsOf: url),
      let list = try? JSONDecoder().decode([Story].self, from: data)
    else { return [] }
    return list
  }()

  static func story(_ id: String) -> Story? { all.first { $0.id == id } }
}

/// Okuma ilerlemesi (yerel). `@salah_stories_progress_v1`: kıssa kimliği → okunan son bölüm (1 tabanlı).
@Observable
final class StoryProgressStore {
  static let shared = StoryProgressStore()
  static let key = "@salah_stories_progress_v1"
  static let lastKey = "@salah_stories_last_v1"

  private(set) var progress: [String: Int]
  private(set) var lastID: String?

  init() {
    progress = LocalStore.decode([String: Int].self, Self.key) ?? [:]
    lastID = LocalStore.string(Self.lastKey)
  }

  func read(_ story: Story) -> Int { min(progress[story.id] ?? 0, story.sections.count) }
  func isDone(_ story: Story) -> Bool { !story.sections.isEmpty && read(story) >= story.sections.count }

  /// Yarım kalan, en son açılan kıssa.
  var resumable: Story? {
    guard let lastID, let story = StoryCatalog.story(lastID) else { return nil }
    let done = read(story)
    return done > 0 && done < story.sections.count ? story : nil
  }

  func opened(_ story: Story) {
    lastID = story.id
    LocalStore.set(story.id, for: Self.lastKey)
  }

  /// `section` 1 tabanlı; geriye düşmez.
  func mark(_ story: Story, section: Int) {
    progress[story.id] = max(progress[story.id] ?? 0, min(section, story.sections.count))
    LocalStore.encode(progress, for: Self.key)
  }
}

enum StoryVerses {
  @MainActor private static var cache: [String: [Verse]] = [:]

  /// Bölümün ayetleri (sure bazında bir kez çekilir, aralık süzülür). Alınamazsa nil.
  @MainActor
  static func load(_ section: StorySection) async -> [TopicVerseText]? {
    let key = "\(Localizer.shared.language.rawValue)_\(section.s)"
    var verses = cache[key]
    if verses == nil {
      let fetched = await QuranService.surah(section.s)
      if !fetched.isEmpty { cache[key] = fetched }
      verses = fetched
    }
    guard let surah = await QuranService.surahs().first(where: { $0.id == section.s }), let verses, !verses.isEmpty else { return nil }
    let range = verses.filter { (section.from...section.to).contains($0.verse_number) }.sorted { $0.verse_number < $1.verse_number }
    guard !range.isEmpty else { return nil }
    return range.map { verse in
      TopicVerseText(
        ref: TopicRef(s: section.s, a: verse.verse_number),
        arabic: verse.verse_simplified,
        text: verse.translation.text.trimmingCharacters(in: .whitespacesAndNewlines),
        source: t("topics.ref", ["surah": surahName(surah), "verse": "\(verse.verse_number)"]),
        page: verse.page_number)
    }
  }
}

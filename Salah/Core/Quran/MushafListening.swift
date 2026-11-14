import Foundation
import Observation

/// Mushafta dinleme: sayfadaki ayetler sırayla okunur, sayfa bitince sonrakine geçilir. Okunan ayet sayfada işaretlenir.
/// Bir ayet bittiği sayfaya aittir; böylece sayfa geçişinde aynı ayet iki kez okunmaz. Android MushafListening.
@MainActor
@Observable
final class MushafListening {
  static let shared = MushafListening()

  /// Dinleme açık mı (duraklatılmış olsa da).
  private(set) var active = false
  private(set) var page = 1
  /// Sayfa değişince okuyucu sayfayı çevirir.
  @ObservationIgnored var onPage: ((Int) -> Void)?

  /// Şu an okunan ayet ("sure:ayet").
  var currentVerse: String? {
    let player = QuranAudioPlayer.shared
    guard active, player.verses.indices.contains(player.activeIndex) else { return nil }
    let verse = player.verses[player.activeIndex]
    return "\(verse.surah_id):\(verse.verse_number)"
  }

  var isPlaying: Bool { QuranAudioPlayer.shared.state == .playing || QuranAudioPlayer.shared.state == .loading }

  /// Sayfadaki ayet sonları sırasıyla ("sure:ayet").
  nonisolated static func verseKeys(_ page: MushafPage) -> [String] {
    var keys: [String] = []
    for line in page.lines {
      for word in line.words ?? [] where word.isEnd && !keys.contains(word.verse) { keys.append(word.verse) }
    }
    return keys
  }

  /// Ayetin Kur'an genelindeki sırası (ses dosyası kimliği): önceki surelerin ayet sayıları + ayet.
  nonisolated static func globalID(_ key: String, surahs: [Surah]) -> Int? {
    let parts = key.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2, surahs.count >= 114 else { return nil }
    let before = surahs.filter { $0.id < parts[0] }.reduce(0) { $0 + $1.verse_count }
    return before + parts[1]
  }

  func start(page: Int, surahs: [Surah]) async {
    active = true
    await play(page: page, surahs: surahs)
  }

  private func play(page: Int, surahs: [Surah]) async {
    guard active, let data = try? await MushafService.page(page), active else {
      if active { stop() }
      return
    }
    self.page = page
    let verses = Self.verseKeys(data).compactMap { key -> Verse? in
      guard let id = Self.globalID(key, surahs: surahs) else { return nil }
      let parts = key.split(separator: ":").compactMap { Int($0) }
      return Verse(id: id, surah_id: parts[0], verse_number: parts[1], verse_simplified: "", page_number: page, juz_number: nil,
        transcription: nil, translation: .init(id: nil, text: "", author: nil))
    }
    guard !verses.isEmpty else { return stop() }
    let player = QuranAudioPlayer.shared
    player.repeatMode = .off
    player.configure(verses)
    player.onFinish = { [weak self] in
      guard let self, self.active else { return }
      guard page < MushafLayout.pageCount else { return self.stop() }
      self.onPage?(page + 1)
      Task { await self.play(page: page + 1, surahs: surahs) }
    }
    player.play(index: 0)
  }

  func toggle() {
    Haptics.impact(.medium)
    QuranAudioPlayer.shared.toggle()
  }

  func stop() {
    active = false
    QuranAudioPlayer.shared.stop()
    QuranAudioPlayer.shared.onFinish = nil
  }
}

/// Mushafta okunan sayfalar: en az 20 sn açık kalan sayfa okundu sayılır, aynı gün aynı sayfa bir kez.
/// Mushaf kapanınca yeni sayfalar Kur'an kaydı olarak eklenir; hatim planı ilerlemesi bu kayıtlardan gelir.
@MainActor
final class MushafReadLog {
  static let shared = MushafReadLog()
  static let dwell: TimeInterval = 20
  private static let key = "@salah_mushaf_read_v1"
  private struct Saved: Codable { var date: String; var pages: [Int] }

  private var current: (page: Int, since: Date)?
  private var session: Set<Int> = []
  /// Bu oturumda okundu sayılan sayfalar (testler için).
  var pendingPages: Set<Int> { session }

  /// Sayfa ekrana geldi (ya da başka sayfaya geçildi).
  func view(_ page: Int, now: Date = Date()) {
    settle(now: now)
    current = (page, now)
  }

  /// Uygulama arka plana geçti ya da mushaf kapandı: açık sayfanın süresi hesaplanır.
  func pause(now: Date = Date()) {
    settle(now: now)
    current = nil
  }

  private func settle(now: Date) {
    guard let current, now.timeIntervalSince(current.since) >= Self.dwell else { return }
    session.insert(current.page)
  }

  /// Bu oturumda okunup bugün henüz sayılmamış sayfalar kaydedilir; sayfa sayısı döner.
  @discardableResult
  func flush(now: Date = Date()) async -> Int {
    pause(now: now)
    let today = localDateString(now)
    var saved = LocalStore.decode(Saved.self, Self.key) ?? Saved(date: today, pages: [])
    if saved.date != today { saved = Saved(date: today, pages: []) }
    let fresh = session.subtracting(saved.pages)
    session = []
    guard !fresh.isEmpty, QuranReadingStore.shared.mushafAutoLog, AuthStore.shared.isAuthenticated, !DebugLaunch.isIsolated else { return 0 }
    do {
      try await TrackerStore.shared.log(.quran, value: .object(["pages": .number(Double(fresh.count)), "source": .string("mushaf")]), notes: nil)
      saved.pages += fresh.sorted()
      LocalStore.encode(saved, for: Self.key)
      return fresh.count
    } catch {
      return 0
    }
  }
}

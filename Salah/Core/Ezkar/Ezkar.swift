import Foundation

/// Sabah ve akşam zikirleri: veri `Resources/ezkar.json` (bu dosya uygulamada değiştirilmez).
enum EzkarSession: String, CaseIterable, Hashable, Sendable {
  case morning, evening

  /// Derin bağlantı: `salah://zikirler/sabah`, `salah://zikirler/aksam`.
  var linkName: String { self == .morning ? "sabah" : "aksam" }
  var labelKey: String { self == .morning ? "ezkar.morning" : "ezkar.evening" }

  init?(link: String?) {
    switch link?.lowercased() {
    case "sabah": self = .morning
    case "aksam", "akşam": self = .evening
    default: return nil
    }
  }
}

/// ezkar.json'daki bir öğe.
struct EzkarSpec: Decodable, Hashable, Identifiable, Sendable {
  let id: String
  /// quran | dua | text
  let kind: String
  let surah: Int?
  let from: Int?
  let to: Int?
  let count: Int

  var target: Int { max(1, count) }
  var ref: TopicRef? {
    guard kind == "quran", let surah, let from else { return nil }
    return TopicRef(s: surah, a: from, to: to)
  }
}

struct EzkarTextSpec: Decodable, Sendable {
  let arabic: String
  let title: [String: String]?
  let source: [String: String]?
  let meaning: [String: String]?
  let transliteration: [String: String]?
}

/// Ekrana hazır öğe: seçili dilde başlık, Arapça, okunuş, anlam ve kaynak. Kur'an öğelerinin metni ayrıca (ağdan/önbellekten) gelir.
struct EzkarCard: Equatable, Identifiable {
  let spec: EzkarSpec
  let title: String
  let arabic: String
  let transliteration: String
  let meaning: String
  let source: String
  var id: String { spec.id }
}

enum EzkarCatalog {
  private struct File: Decodable {
    let morning: [EzkarSpec]
    let evening: [EzkarSpec]
    let titles: [String: [String: String]]
    let texts: [String: EzkarTextSpec]
  }

  private static let file: File? = {
    guard let url = Bundle.main.url(forResource: "ezkar", withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(File.self, from: data)
  }()

  static func specs(_ session: EzkarSession) -> [EzkarSpec] {
    guard let file else { return [] }
    return session == .morning ? file.morning : file.evening
  }

  /// Seçili dil, yoksa İngilizce, o da yoksa Türkçe. Anahtar varsa boş değer de geçerlidir (Arapça'da anlam boş).
  static func pick(_ map: [String: String]?, language: String) -> String {
    guard let map else { return "" }
    if let value = map[language] { return value }
    return map["en"] ?? map["tr"] ?? ""
  }

  /// Oturumun öğeleri seçili dilde. Kaynağı bulunamayan dua atlanır.
  static func cards(_ session: EzkarSession, language: String = Localizer.shared.language.rawValue,
                    duas: [Dua] = DuaLibrary.allDuas) -> [EzkarCard] {
    guard let file else { return [] }
    let byID = Dictionary(duas.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    return specs(session).compactMap { spec in
      switch spec.kind {
      case "quran":
        return EzkarCard(spec: spec, title: pick(file.titles[spec.id], language: language), arabic: "", transliteration: "", meaning: "", source: "")
      case "dua":
        guard let dua = byID[spec.id] else { return nil }
        return EzkarCard(spec: spec, title: dua.title, arabic: dua.arabic, transliteration: dua.transliteration, meaning: dua.turkish,
                         source: dua.source ?? "")
      case "text":
        guard let text = file.texts[spec.id] else { return nil }
        return EzkarCard(spec: spec, title: pick(text.title, language: language), arabic: text.arabic,
                         transliteration: pick(text.transliteration, language: language), meaning: pick(text.meaning, language: language),
                         source: pick(text.source, language: language))
      default: return nil
      }
    }
  }

  /// Varsayılan oturum: ikindi vaktinden önce Sabah, sonra Akşam. Vakit yoksa 15.30.
  static func defaultSession(now: Date, ikindi: String?, calendar: Calendar = .current) -> EzkarSession {
    let cutoff = ikindi.flatMap { NotificationPlan.clock($0, on: now, calendar: calendar) }
      ?? calendar.date(bySettingHour: 15, minute: 30, second: 0, of: now) ?? now
    return now < cutoff ? .morning : .evening
  }

  @MainActor
  static func todayIkindi(now: Date = Date()) -> String? {
    let today = Calendar.current.startOfDay(for: now)
    return PrayerTimesService.cachedDays(districtId: Locations.selectedDistrictId).first { $0.localDay == today }?.times.ikindi
  }
}

/// Gün ve oturum başına yerel ilerleme (`@salah_ezkar_progress_v1`); ertesi gün sıfırlanır. Sunucu yok.
@Observable
final class EzkarProgressStore {
  static let shared = EzkarProgressStore()
  static let key = "@salah_ezkar_progress_v1"

  struct State: Codable, Equatable {
    var date: String
    var morning: [String: Int] = [:]
    var evening: [String: Int] = [:]

    func counts(_ session: EzkarSession) -> [String: Int] { session == .morning ? morning : evening }
  }

  private(set) var state: State
  @ObservationIgnored private let today: () -> String
  @ObservationIgnored private let persists: Bool

  init(today: @escaping () -> String = { localDateString() }, persists: Bool = true) {
    self.today = today
    self.persists = persists
    let stored = persists ? LocalStore.decode(State.self, Self.key) : nil
    state = stored?.date == today() ? stored! : State(date: today())
  }

  private func rollover() {
    if state.date != today() { state = State(date: today()) }
  }

  func count(_ session: EzkarSession, _ id: String) -> Int {
    state.date == today() ? state.counts(session)[id] ?? 0 : 0
  }

  func isDone(_ spec: EzkarSpec, _ session: EzkarSession) -> Bool { count(session, spec.id) >= spec.target }

  func completedCount(_ session: EzkarSession, specs: [EzkarSpec]) -> Int { specs.filter { isDone($0, session) }.count }

  func isComplete(_ session: EzkarSession, specs: [EzkarSpec]) -> Bool {
    !specs.isEmpty && specs.allSatisfy { isDone($0, session) }
  }

  /// Sayacı 1 artırır (hedefte durur). Öğe bu dokunuşla tamamlandıysa true.
  @discardableResult
  func tap(_ session: EzkarSession, _ spec: EzkarSpec) -> Bool {
    rollover()
    let before = count(session, spec.id)
    guard before < spec.target else { return false }
    set(session, spec.id, before + 1)
    return before + 1 >= spec.target
  }

  func reset(_ session: EzkarSession, _ id: String) {
    rollover()
    set(session, id, 0)
  }

  private func set(_ session: EzkarSession, _ id: String, _ value: Int) {
    if session == .morning { state.morning[id] = value > 0 ? value : nil } else { state.evening[id] = value > 0 ? value : nil }
    if persists { LocalStore.encode(state, for: Self.key) }
  }

  /// O gün tamamlanan oturumlar (hatırlatma planlanmaz). Öğesi olmayan oturum tamamlanmış sayılmaz.
  func completedSessions(date: String) -> Set<EzkarSession> {
    guard state.date == date else { return [] }
    return Set(EzkarSession.allCases.filter { isComplete($0, specs: EzkarCatalog.specs($0)) })
  }

  var signature: String {
    completedSessions(date: today()).map(\.rawValue).sorted().joined(separator: ",")
  }
}

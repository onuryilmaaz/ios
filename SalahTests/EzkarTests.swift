import Foundation
import Testing
@testable import Salah

@MainActor
struct EzkarTests {
  private var cal: Calendar { NotificationFixtures.calendar }

  @Test func catalogHasBothSessionsAndResolvesEveryItem() {
    for session in EzkarSession.allCases {
      let specs = EzkarCatalog.specs(session)
      #expect(specs.count >= 8)
      // Her dua ve metin öğesi seçili dilde çözülür; Kur'an öğeleri metni sonradan alır.
      #expect(EzkarCatalog.cards(session, language: "tr").count == specs.count)
      #expect(EzkarCatalog.cards(session, language: "en").count == specs.count)
    }
  }

  @Test func arabicMeaningIsEmptyAndTransliterationHiddenByView() {
    let cards = EzkarCatalog.cards(.morning, language: "ar")
    let text = cards.first { $0.spec.kind == "text" }
    #expect(text != nil && text?.meaning == "" && !(text?.arabic.isEmpty ?? true))
    #expect(EzkarCatalog.pick(["tr": "a", "en": "b"], language: "de") == "b")
    #expect(EzkarCatalog.pick(["tr": "a"], language: "de") == "a")
  }

  @Test func quranItemsCarryRanges() {
    let nas = EzkarCatalog.specs(.morning).first { $0.id == "nas" }
    #expect(nas?.ref == TopicRef(s: 114, a: 1, to: 6))
    #expect(nas?.target == 3)
  }

  @Test func defaultSessionSwitchesAtAsr() {
    #expect(EzkarCatalog.defaultSession(now: NotificationFixtures.date(19, 9), ikindi: "16:13", calendar: cal) == .morning)
    #expect(EzkarCatalog.defaultSession(now: NotificationFixtures.date(19, 16, 12), ikindi: "16:13", calendar: cal) == .morning)
    #expect(EzkarCatalog.defaultSession(now: NotificationFixtures.date(19, 16, 13), ikindi: "16:13", calendar: cal) == .evening)
    #expect(EzkarCatalog.defaultSession(now: NotificationFixtures.date(19, 20), ikindi: nil, calendar: cal) == .evening)
    #expect(EzkarCatalog.defaultSession(now: NotificationFixtures.date(19, 9), ikindi: nil, calendar: cal) == .morning)
  }

  @Test func countsUpToTargetCompletesAndResets() {
    var day = "2026-10-19"
    let store = EzkarProgressStore(today: { day }, persists: false)
    let spec = EzkarSpec.make("a", count: 3)
    #expect(!store.tap(.morning, spec) && !store.tap(.morning, spec))
    #expect(store.tap(.morning, spec))
    #expect(store.isDone(spec, .morning) && !store.isDone(spec, .evening))
    // Hedefte durur.
    #expect(!store.tap(.morning, spec) && store.count(.morning, "a") == 3)
    store.reset(.morning, "a")
    #expect(store.count(.morning, "a") == 0)
    // Ertesi gün sıfırlanır.
    store.tap(.morning, spec)
    day = "2026-10-20"
    #expect(store.count(.morning, "a") == 0)
    #expect(!store.tap(.morning, spec) && store.count(.morning, "a") == 1)
  }

  @Test func sessionCompletionNeedsAllItems() {
    let store = EzkarProgressStore(today: { "2026-10-19" }, persists: false)
    let specs = [EzkarSpec.make("a", count: 1), EzkarSpec.make("b", count: 2)]
    store.tap(.evening, specs[0])
    #expect(store.completedCount(.evening, specs: specs) == 1 && !store.isComplete(.evening, specs: specs))
    store.tap(.evening, specs[1]); store.tap(.evening, specs[1])
    #expect(store.isComplete(.evening, specs: specs))
    #expect(!store.isComplete(.morning, specs: specs))
    #expect(!store.isComplete(.evening, specs: []))
  }

  @Test func reminderTimesAndCompletedSessionIsSkipped() {
    var p = NotificationFixtures.enabled
    p.ezkarMorning = true
    p.ezkarEvening = true
    let now = NotificationFixtures.date(19, 5)
    let plan = NotificationPlan.build(days: NotificationFixtures.days, preferences: p, now: now, calendar: cal).filter { $0.kind == .ezkar }
    // Güneş 06:49 + 20 dk, ikindi 16:13 + 30 dk.
    #expect(plan.first { $0.when == "morning" }?.date == NotificationFixtures.date(19, 7, 9))
    #expect(plan.first { $0.when == "evening" }?.date == NotificationFixtures.date(19, 16, 43))
    #expect(plan.count == 8)
    // Bugünkü sabah tamamlandı: yalnız bugünün sabahı düşer.
    let done = NotificationPlan.build(days: NotificationFixtures.days, preferences: p, now: now, calendar: cal, ezkarDone: [.morning]).filter { $0.kind == .ezkar }
    #expect(done.count == 7 && !done.contains { $0.date == NotificationFixtures.date(19, 7, 9) })
    #expect(done.contains { $0.date == NotificationFixtures.date(20, 7, 9) })
  }

  @Test func remindersAreOffByDefaultAndPersist() {
    let p = NotificationPreferences.read(get: { _ in nil })
    #expect(!p.ezkarMorning && !p.ezkarEvening)
    let on = NotificationPreferences.read(get: { ["EZKAR_MORNING_REMINDER_ENABLED": "true"][$0] })
    #expect(on.ezkarMorning && !on.ezkarEvening)
    var off = NotificationFixtures.enabled
    off.ezkarMorning = false
    #expect(!NotificationPlan.build(days: NotificationFixtures.days, preferences: off, now: NotificationFixtures.date(19, 5), calendar: cal).contains { $0.kind == .ezkar })
  }

  @Test func deepLinks() {
    #expect(AppLinks.target(for: URL(string: "salah://zikirler")!) == .home(.ezkar(nil)))
    #expect(AppLinks.target(for: URL(string: "salah://zikirler/sabah")!) == .home(.ezkar(.morning)))
    #expect(AppLinks.target(for: URL(string: "salah://zikirler/aksam")!) == .home(.ezkar(.evening)))
    #expect(AppLinks.target(for: URL(string: "salah://zikirler/baska")!) == .home(.ezkar(nil)))
    #expect(AppLinks.target(for: URL(string: "salah://gunun-okumasi")!) == .home(.dailyReading))
  }

  @Test func verseAudioUsesGlobalVerseNumbers() async {
    let refs = VerseAudio.refs(surah: 112, from: 1, to: 4)
    #expect(refs.map(\.a) == [1, 2, 3, 4])
    #expect(VerseAudio.refs(surah: 1, from: 3, to: 2).isEmpty)
  }
}

extension EzkarSpec {
  static func make(_ id: String, count: Int) -> EzkarSpec {
    let json = #"{"id":"\#(id)","kind":"text","count":\#(count)}"#
    return try! JSONDecoder().decode(EzkarSpec.self, from: Data(json.utf8))
  }
}

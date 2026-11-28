import Foundation
import Testing
@testable import Salah

@MainActor
struct TopicsTests {
  @Test func catalogLoadsAllTopicsWithVerses() {
    let ids = ["sabir", "sukur", "tevekkul", "umut", "tovbe", "iman", "dua", "huzur", "siginma", "ahlak", "aile", "rizik"]
    #expect(TopicCatalog.all.map(\.id) == ids)
    #expect(TopicCatalog.all.allSatisfy { !$0.verses.isEmpty && $0.verses.allSatisfy { $0.s > 0 && $0.a > 0 && $0.to >= $0.a } })
  }

  @Test func refIdRoundTripAndRangeDefaults() throws {
    let ref = TopicRef(s: 2, a: 153)
    #expect(ref.to == 153 && ref.id == "2:153:153")
    #expect(TopicRef(id: "3:1:4") == TopicRef(s: 3, a: 1, to: 4))
    #expect(TopicRef(id: "bozuk") == nil)
    let json = #"{"s":2,"a":153}"#.data(using: .utf8)!
    #expect(try JSONDecoder().decode(TopicRef.self, from: json).to == 153)
  }

  @Test func dailyPickIsStableAndBounded() {
    let topics = TopicCatalog.all.map(\.id)
    let a = TopicPicker.day(topics, date: "2026-11-28")
    #expect(a == TopicPicker.day(topics, date: "2026-11-28"))
    #expect(a.count <= TopicDay.maxItems && Set(a.map(\.id)).count == a.count)
    #expect(TopicPicker.day([], date: "2026-11-28").isEmpty)
    #expect(TopicCatalog.refs(for: ["yok"]).isEmpty)
  }

  @Test func savedStoreTogglesAndPersists() {
    let store = TopicSavedStore()
    let before = store.ids
    let ref = TopicRef(s: 114, a: 6)
    store.toggle(ref)
    #expect(store.isSaved(ref) && store.refs.first == ref)
    #expect(TopicSavedStore().isSaved(ref))
    store.toggle(ref)
    #expect(!store.isSaved(ref) && store.ids == before)
    LocalStore.encode(before, for: TopicSavedStore.key)
  }

  @Test func widgetSlicesCycleEveryFourHours() {
    // Widget tarafı ayrı hedef; dilim kuralı: saat / 4, öğe sayısına sarar.
    #expect(TopicDay.maxItems == 24 / 4)
  }
}

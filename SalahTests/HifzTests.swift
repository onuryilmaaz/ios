import Foundation
import Testing
@testable import Salah

/// Android HifzPlanTest ile aynı girdiler.
struct HifzPlanTests {
  let cal = Calendar.current
  var today: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 12))! }
  func gap(_ due: String) -> Int {
    let d = HifzPlan.day(today)
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return cal.dateComponents([.day], from: f.date(from: d)!, to: f.date(from: due)!).day!
  }
  var card: HifzPlan.Card { .init(surah: 108, verse: 1, globalId: 6205, due: HifzPlan.day(today)) }

  @Test func rememberedClimbsBoxes() {
    var c = card
    var gaps: [Int] = []
    for _ in 0..<7 { c = HifzPlan.rate(c, .remembered, today: today); gaps.append(gap(c.due)) }
    #expect(gaps == [2, 4, 7, 15, 30, 30, 30])
    #expect(c.box == 5)
  }

  @Test func hardHalvesAndForgotResets() {
    var strong = card
    strong.box = 4
    #expect(gap(HifzPlan.rate(strong, .hard, today: today).due) == 7)
    let forgot = HifzPlan.rate(strong, .forgot, today: today)
    #expect(forgot.box == 0 && forgot.lapses == 1 && gap(forgot.due) == 1)
    #expect(gap(HifzPlan.rate(card, .hard, today: today).due) == 1)
  }

  @Test func addSkipsExistingAndDueSorts() {
    let list = HifzPlan.add([card], surah: 108, verses: [(1, 6205), (2, 6206), (3, 6207)], today: today)
    #expect(list.count == 3)
    let later = list.map { c -> HifzPlan.Card in
      var c = c
      if c.verse == 2 { c.due = HifzPlan.day(today, plus: 3) }
      return c
    }
    #expect(HifzPlan.due(later, today: today).map(\.verse) == [1, 3])
  }
}

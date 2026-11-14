import Foundation
import Testing
@testable import Salah

/// Tesbihat: 33/33/33 ve bir tehlil; serbest zikirde hedefin katlarında bildirim.
struct DhikrPlanTests {
  @Test func tesbihatRunsThroughAllSteps() {
    var s = DhikrPlan.Tesbihat()
    var events: [DhikrPlan.Event] = []
    for _ in 0..<100 {
      let (next, event) = DhikrPlan.tap(s)
      s = next
      events.append(event)
    }
    #expect(events.filter { $0 == .stepDone }.count == 3)
    #expect(events.last == .finished)
    #expect(s.done)
    #expect(events[32] == .stepDone && events[65] == .stepDone && events[98] == .stepDone)
    // Tamamlandıktan sonra sayaç ilerlemez.
    #expect(DhikrPlan.tap(s).0 == s)
  }

  @Test func freeTargetMultiples() {
    #expect(DhikrPlan.reachedTarget(count: 33, target: 33))
    #expect(DhikrPlan.reachedTarget(count: 66, target: 33))
    #expect(!DhikrPlan.reachedTarget(count: 34, target: 33))
    #expect(!DhikrPlan.reachedTarget(count: 50, target: 0))
  }

  @Test func everyItemHasTexts() {
    for item in DhikrItem.all + [DhikrItem.tesbihatClosing] {
      #expect(!item.arabic.isEmpty)
      for part in ["name", "short", "meaning"] { #expect(t("dhikr.items.\(item.id).\(part)") != "dhikr.items.\(item.id).\(part)") }
    }
    for step in DhikrPlan.tesbihat { #expect(DhikrItem.find(step.id) != nil) }
  }
}

/// App Group durumu: gün değişince bugün sıfırlanır, serbest modda hedef bildirilir.
struct DhikrSharedTests {
  @Test func dayRollResetsToday() {
    var s = DhikrShared.State()
    s.day = "2000-01-01"
    s.today = 50
    let (next, _) = DhikrShared.tap(s)
    #expect(next.today == 1)
    #expect(next.day == DhikrShared.dayString(Date()))
  }

  @Test func freeModeCountsToTarget() {
    var s = DhikrShared.State()
    s.mode = "free"
    s.target = 3
    var events: [DhikrShared.Event] = []
    for _ in 0..<3 { let r = DhikrShared.tap(s); s = r.0; events.append(r.1) }
    #expect(events == [.counted, .counted, .stepDone])
    #expect(s.current.count == 3)
  }

  @Test func roundTripsThroughDefaults() {
    let defaults = UserDefaults(suiteName: "test.dhikr.\(UUID().uuidString)")!
    var s = DhikrShared.State()
    s.itemId = "salavat"
    DhikrShared.save(s, defaults)
    #expect(DhikrShared.load(defaults) == s)
  }
}

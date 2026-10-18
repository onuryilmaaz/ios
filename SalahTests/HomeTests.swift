import Foundation
import Testing
@testable import Salah

@MainActor
struct HomeLayoutReconcileTests {
  typealias S = HomeLayoutStore.Section

  @Test func keepsUserOrderAndVisibility() {
    let stored = HomeLayoutStore.defaults.reversed().map { S(key: $0.key, visible: $0.key != .streak) }
    let result = HomeLayoutStore.reconcile(Array(stored))
    #expect(result.map(\.key) == HomeLayoutStore.defaults.reversed().map(\.key))
    #expect(result.first { $0.key == .streak }?.visible == false)
  }

  /// Güncellemeyle gelen kart, varsayılan sırada kendinden önceki kartın arkasına girer.
  @Test func insertsNewKeyAfterItsDefaultPredecessor() {
    let stored = [S(key: .streak, visible: true), S(key: .prayerTracker, visible: true)]
    let keys = HomeLayoutStore.reconcile(stored).map(\.key)
    // alarms varsayılanda prayerTracker'dan sonra gelir.
    #expect(keys.firstIndex(of: .alarms) == keys.firstIndex(of: .prayerTracker)! + 1)
    #expect(Set(keys) == Set(HomeLayoutStore.Key.allCases))
  }

  @Test func dropsDuplicates() {
    let stored = [S(key: .streak, visible: true), S(key: .streak, visible: false)]
    let result = HomeLayoutStore.reconcile(stored)
    #expect(result.filter { $0.key == .streak }.count == 1)
    #expect(result.first { $0.key == .streak }?.visible == true)
  }
}

@MainActor
struct NarrationTextTests {
  @Test func removesCitationTailAndFootnotes() {
    let raw = "Resulullah buyurdu ki [61] amel niyete göredir. Diğer tahric: Müslim 4/1713 (2176), Buhari"
    #expect(cleanNarrationText(raw) == "Resulullah buyurdu ki amel niyete göredir.")
  }

  /// "tekrar:" ardından sayı gelmiyorsa hadisin kendi metnidir, kesilmez.
  @Test func keepsRepeatWordWithoutNumbers() {
    let raw = "Üç kere tekrar: \"Ey Muaz\" dedi."
    #expect(cleanNarrationText(raw) == raw)
  }

  @Test func removesRepeatReferences() {
    #expect(cleanNarrationText("Metin. Tekrar: 54, 2529, 3898.") == "Metin.")
  }

  @Test func keepsTranslatorBraces() {
    let raw = "Yetim {bakıma muhtaç} çocuk {...} korunur."
    #expect(cleanNarrationText(raw) == "Yetim {bakıma muhtaç} çocuk … korunur.")
  }
}

@MainActor
struct WeekDaysTests {
  let names = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

  /// 18 Ekim 2026 Pazar.
  var now: Date { Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12))! }

  @Test func lastSevenDaysEndWithToday() {
    let days = WeekDay.build(daily: nil, dayNames: names, now: now)
    #expect(days.map(\.label) == ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"])
    #expect(days.last?.isToday == true)
  }

  @Test func matchesCountsByLocalDay() {
    let daily: JSONValue = .array([
      ["date": "2026-10-18", "prayer_count": .number(5)],
      ["date": "2026-10-16", "prayer_count": "3"],
    ])
    let days = WeekDay.build(daily: daily, dayNames: names, now: now)
    #expect(days[6].full)
    #expect(days[4].partial && days[4].count == 3)
    #expect(days[5].count == 0)
  }
}

@MainActor
struct SVGPathTests {
  /// Google logosunun parçaları 48×48 kutuyu doldurmalı (sıkışık yazım: "-.15", "s.27-3.14.76").
  @Test func parsesCompactSyntaxWithinViewBox() {
    let p = SVGPath.parse("M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z")
    let b = p.boundingRect
    #expect(b.minX >= -0.01 && b.maxX <= 10.6)
    #expect(abs(b.minY - 13.22) < 0.1)
    #expect(abs(b.maxY - 34.78) < 0.1)
  }

  @Test func horizontalAndVerticalCommands() {
    let b = SVGPath.parse("M0 0H10V5h-4v5z").boundingRect
    #expect(b == CGRect(x: 0, y: 0, width: 10, height: 10))
  }
}

@MainActor
struct LocationsTests {
  @Test(arguments: ["İstanbul", "ISTANBUL", "Istanbul", "istanbul "])
  func matchesStateIgnoringTurkishCase(region: String) {
    #expect(Locations.state(matching: region)?.name == "İSTANBUL")
  }

  @Test func defaultDistrictIsProvinceCenter() {
    let ankara = Locations.state(matching: "Ankara")!
    #expect(Locations.defaultDistrict(ofState: ankara._id)?.name == "ANKARA")
  }

  @Test func unknownRegionIsNil() {
    #expect(Locations.state(matching: "Bavaria") == nil)
  }
}

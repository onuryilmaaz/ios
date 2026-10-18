import Foundation
import Testing
@testable import Salah

@MainActor
struct TrackerTextTests {
  func log(_ type: ActivityType, _ value: JSONValue, id: String = "1") -> TrackerLog {
    TrackerLog(id: id, date: "2026-10-18", activity_type: type.rawValue, value: value, notes: nil, created_at: nil)
  }

  @Test func aggregatesPerType() {
    let logs = [
      log(.quran, ["pages": .number(4)]),
      log(.quran, ["pages": .number(6), "minutes": .number(20)]),
      log(.memorization, ["new_ayets": .number(3), "revision_ayets": .number(5)]),
      log(.fasting, ["type": "nafile"]),
    ]
    #expect(TrackerText.aggregate(logs, .quran) == 10)
    #expect(TrackerText.aggregate(logs, .memorization) == 8)
    #expect(TrackerText.aggregate(logs, .fasting) == 1)
    #expect(TrackerText.aggregate(logs, .dua) == 0)
  }

  /// Değer etiketi RN ile aynı parçaları üretmeli (sayılar ".0" olmadan).
  @Test func valueLabelsMatchRN() {
    let tr = { (k: String, v: [String: any CustomStringConvertible]) in t(k, v) }
    #expect(TrackerText.valueLabel(log(.quran, ["pages": .number(4)])) == tr("tracker.value.pages", ["count": "4"]))
    #expect(
      TrackerText.valueLabel(log(.quran, ["pages": .number(4), "minutes": .number(20)]))
        == tr("tracker.value.pages", ["count": "4"]) + " · " + tr("tracker.value.minutesShort", ["count": "20"]))
    #expect(
      TrackerText.valueLabel(log(.nafile, ["type": "vitir", "rakaat": .number(3)]))
        == "\(t("tracker.nafile.vitir")) · \(tr("tracker.value.rakaat", ["count": "3"]))")
    #expect(TrackerText.valueLabel(log(.fasting, ["type": "pazartesi_persembe"])) == t("tracker.fasting.pazartesi_persembeShort"))
  }

  @Test func unknownNafileTypeFallsBackToRaw() {
    #expect(TrackerText.nafile("yeni_tur") == "yeni_tur")
  }

  @Test func decodesNumericIdAndRemovedType() throws {
    let raw = #"{"id":42,"date":"2026-10-18","activity_type":"zikir","value":{"count":33}}"#
    let log = try JSONDecoder().decode(TrackerLog.self, from: Data(raw.utf8))
    #expect(log.id == "42")
    #expect(log.type == nil)
  }
}

@MainActor
struct HeatmapTests {
  @Test func lastColumnIsTodaysWeekAndFutureIsBlank() {
    // 18 Ekim 2026 Pazar: son sütunun son hücresi bugün, gelecek gün yok.
    let history = InsightsStore.History(
      from: "2025-10-12", to: "2026-10-18",
      days: [.init(date: "2026-10-18", count: 5, kaza: 0), .init(date: "2026-10-12", count: 2, kaza: 0)],
      ozelGun: ["2026-10-14"])
    let cols = Heatmap.build(history)
    #expect(cols.count == 53)
    let last = cols.last!.cells
    #expect(last.first?.date == "2026-10-12")
    #expect(last.last?.date == "2026-10-18")
    #expect(last.last?.count == 5)
    #expect(last[2].ozelGun)
    #expect(!last.contains { $0.future })
  }

  @Test func midWeekLeavesFutureCells() {
    let history = InsightsStore.History(from: "2025-10-10", to: "2026-10-14", days: [], ozelGun: [])
    let last = Heatmap.build(history).last!.cells
    #expect(last.filter(\.future).count == 4)
  }

  @Test(arguments: [(0, 0), (1, 1), (2, 1), (3, 2), (4, 2), (5, 3)])
  func levels(count: Int, level: Int) {
    #expect(Heatmap.level(count) == level)
  }
}

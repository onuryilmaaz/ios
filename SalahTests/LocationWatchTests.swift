import Foundation
import Testing
@testable import Salah

/// Android LocationWatchTest ile aynı kararlar (RN services/locationWatch.service.ts).
@MainActor
struct LocationWatchTests {
  // İzmit (Kocaeli) ve İstanbul Kadıköy: ~85 km; İzmit içinde birkaç km.
  private let izmit = (40.7654, 29.9408)
  private let kadikoy = (40.9909, 29.0303)
  private let izmitNear = (40.7800, 29.9800)

  @Test func distanceIsGreatCircleKm() {
    #expect(LocationWatch.distanceKm(izmit.0, izmit.1, izmit.0, izmit.1) == 0)
    let d = LocationWatch.distanceKm(izmit.0, izmit.1, kadikoy.0, kadikoy.1)
    #expect((75.0...90.0).contains(d))
    #expect(abs(d - LocationWatch.distanceKm(kadikoy.0, kadikoy.1, izmit.0, izmit.1)) < 1e-9)
  }

  @Test func resolveIsSkippedOnlyWhenNotMovedAndSameDistrict() {
    let prev = LocationWatch.Resolved(lat: izmit.0, lon: izmit.1, districtId: "9654")
    #expect(LocationWatch.needsResolve(nil, lat: izmit.0, lon: izmit.1, currentDistrictId: "9654"))
    #expect(!LocationWatch.needsResolve(prev, lat: izmitNear.0, lon: izmitNear.1, currentDistrictId: "9654"))
    #expect(LocationWatch.needsResolve(prev, lat: kadikoy.0, lon: kadikoy.1, currentDistrictId: "9654"))
    // Kocaeli'ndeyken ayarlardan başka il seçildi: koordinat aynı, ilçe uyuşmuyor.
    #expect(LocationWatch.needsResolve(prev, lat: izmit.0, lon: izmit.1, currentDistrictId: "9300"))
  }

  @Test func decidesSilentUpdateAskOrNothing() {
    #expect(LocationWatch.decide(currentDistrictId: "1", resolvedDistrictId: "1", source: "manual", declinedDistrictId: nil) == .none)
    #expect(LocationWatch.decide(currentDistrictId: "1", resolvedDistrictId: "2", source: "auto", declinedDistrictId: "2") == .silentUpdate)
    #expect(LocationWatch.decide(currentDistrictId: "1", resolvedDistrictId: "2", source: "manual", declinedDistrictId: nil) == .ask)
    // Kaynağı bilinmeyen eski kurulum elle seçilmiş sayılır.
    #expect(LocationWatch.decide(currentDistrictId: "1", resolvedDistrictId: "2", source: nil, declinedDistrictId: nil) == .ask)
    // "Kalsın" denen ilçe tekrar sorulmaz, başka bir ilçe sorulur.
    #expect(LocationWatch.decide(currentDistrictId: "1", resolvedDistrictId: "2", source: "manual", declinedDistrictId: "2") == .none)
    #expect(LocationWatch.decide(currentDistrictId: "1", resolvedDistrictId: "3", source: "manual", declinedDistrictId: "2") == .ask)
  }
}

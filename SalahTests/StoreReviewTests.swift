import Foundation
import Testing
@testable import Salah

/// Android StoreReviewTest ile aynı kurallar.
struct StoreReviewTests {
  let now = Date(timeIntervalSince1970: 2_000_000_000)

  @Test func streakNeedsSevenDays() {
    #expect(!StoreReview.shouldRequest(streak: 6, lastRaw: nil, now: now))
    #expect(StoreReview.shouldRequest(streak: 7, lastRaw: nil, now: now))
  }

  @Test func momentWithoutStreak() {
    #expect(StoreReview.shouldRequest(streak: nil, lastRaw: nil, now: now))
  }

  @Test func waits120Days() {
    let recent = String(Int((now.timeIntervalSince1970 - 30 * 86400) * 1000))
    let old = String(Int((now.timeIntervalSince1970 - 121 * 86400) * 1000))
    #expect(!StoreReview.shouldRequest(streak: nil, lastRaw: recent, now: now))
    #expect(StoreReview.shouldRequest(streak: nil, lastRaw: old, now: now))
    #expect(StoreReview.shouldRequest(streak: 10, lastRaw: "bozuk", now: now))
  }
}

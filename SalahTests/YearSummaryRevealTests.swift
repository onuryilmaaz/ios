import Foundation
import Testing
@testable import Salah

/// Yıl özeti yalnız Ocak ayında, biten yıl için açılır. Android YearSummaryRevealTest.
@MainActor
struct YearSummaryRevealTests {
  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
  }

  @Test func revealStartsAtTenOnJanuaryFirst() {
    #expect(YearSummaryStore.revealedYear(now: date(2027, 1, 1, 9, 59)) == nil)
    #expect(YearSummaryStore.revealedYear(now: date(2027, 1, 1, 10, 0)) == 2026)
    #expect(YearSummaryStore.revealedYear(now: date(2027, 1, 2, 0, 30)) == 2026)
  }

  @Test func januaryRevealsPreviousYear() {
    #expect(YearSummaryStore.revealedYear(now: date(2027, 1, 1)) == 2026)
    #expect(YearSummaryStore.revealedYear(now: date(2027, 1, 31)) == 2026)
  }

  @Test func otherMonthsRevealNothing() {
    #expect(YearSummaryStore.revealedYear(now: date(2026, 11, 15)) == nil)
    #expect(YearSummaryStore.revealedYear(now: date(2026, 12, 31)) == nil)
    #expect(YearSummaryStore.revealedYear(now: date(2027, 2, 1)) == nil)
  }
}

import Foundation
import Testing
@testable import Salah

@MainActor
struct MushafListeningTests {
  private func surahs() -> [Surah] {
    (1...114).map { id in
      Surah(id: id, name: "\(id)", verse_count: id == 1 ? 7 : id == 2 ? 286 : 1, page_number: nil, revelation_order: nil, revelation_place: nil, name_arabic: nil)
    }
  }

  @Test func globalIdCountsPreviousSurahs() {
    #expect(MushafListening.globalID("1:1", surahs: surahs()) == 1)
    #expect(MushafListening.globalID("2:5", surahs: surahs()) == 12)
    #expect(MushafListening.globalID("3:1", surahs: surahs()) == 294)
    #expect(MushafListening.globalID("bad", surahs: surahs()) == nil)
  }

  @Test func verseBelongsToPageWhereItEnds() {
    let w = { (verse: String, end: Bool) in MushafWord(text: "x", isEnd: end, verse: verse) }
    let page = MushafPage(page: 3, lines: [
      MushafLine(kind: "text", words: [w("2:6", false), w("2:6", true), w("2:7", false)]),
      MushafLine(kind: "text", words: [w("2:7", false), w("2:7", true)]),
    ], centered: false, surahId: 2, juz: 1)
    #expect(MushafListening.verseKeys(page) == ["2:6", "2:7"])
  }

  @Test func pageCountsAfterDwell() {
    let log = MushafReadLog()
    let start = Date(timeIntervalSince1970: 1_000_000)
    log.view(10, now: start)
    log.view(11, now: start.addingTimeInterval(25))
    log.view(12, now: start.addingTimeInterval(30))
    log.pause(now: start.addingTimeInterval(55))
    #expect(log.pendingPages == [10, 12])
  }

  /// Kitap düzeni (Duo): açılımdaki her sayfa kendi bekleme süresini doldurunca sayılır, önce sağdaki.
  @Test func spreadCountsEachPageAfterItsOwnDwell() {
    let log = MushafReadLog()
    let start = Date(timeIntervalSince1970: 1_000_000)
    log.view([3, 4], now: start)
    log.view([5, 6], now: start.addingTimeInterval(25))
    log.view([7, 8], now: start.addingTimeInterval(70))
    log.pause(now: start.addingTimeInterval(75))
    #expect(log.pendingPages == [3, 5, 6])
  }
}

/// Android MushafMarksTest.
struct MushafMarksTests {
  @Test func rubOrderMapsToJuzHizbAndQuarters() {
    #expect(MushafMarks.kind(rub: 1) == .juz(1))
    #expect(MushafMarks.kind(rub: 2) == .quarter(hizb: 1, part: 1))
    #expect(MushafMarks.kind(rub: 4) == .quarter(hizb: 1, part: 3))
    #expect(MushafMarks.kind(rub: 5) == .hizb(2))
    #expect(MushafMarks.kind(rub: 9) == .juz(2))
    #expect(MushafMarks.kind(rub: 240) == .quarter(hizb: 60, part: 3))
  }

  /// Gerçek veriden: 2:26 ilk hizbin 1. çeyreğinin başı (Medine Mushafı 5. sayfa).
  @Test func bundledDataHasAllQuartersAndSajdahs() {
    let page = MushafPage(page: 5, lines: [
      MushafLine(kind: "text", words: [MushafWord(text: "x", isEnd: false, verse: "2:26")]),
    ], centered: false, surahId: 2, juz: 1)
    #expect(MushafMarks.marks(for: page) == [0: .quarter(hizb: 1, part: 1)])
  }
}

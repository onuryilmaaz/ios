import Foundation
import Testing
@testable import Salah

/// Cihazda hesaplanan vakitler Diyanet tablosundan en fazla 2 dakika sapmalı (İstanbul 2026 verisi).
@MainActor
struct PrayerCalcTests {
  var calendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return cal
  }

  let diyanet: [(String, PrayerTimes)] = [
    ("2026-01-15", .init(imsak: "06:50", gunes: "08:20", ogle: "13:18", ikindi: "15:45", aksam: "18:07", yatsi: "19:31")),
    ("2026-03-20", .init(imsak: "05:36", gunes: "07:01", ogle: "13:17", ikindi: "16:41", aksam: "19:22", yatsi: "20:42")),
    ("2026-06-21", .init(imsak: "03:24", gunes: "05:25", ogle: "13:11", ikindi: "17:11", aksam: "20:47", yatsi: "22:38")),
    ("2026-09-23", .init(imsak: "05:20", gunes: "06:45", ogle: "13:02", ikindi: "16:26", aksam: "19:08", yatsi: "20:28")),
    ("2026-11-14", .init(imsak: "06:15", gunes: "07:43", ogle: "12:53", ikindi: "15:30", aksam: "17:54", yatsi: "19:17")),
    ("2026-12-21", .init(imsak: "06:46", gunes: "08:18", ogle: "13:07", ikindi: "15:25", aksam: "17:46", yatsi: "19:12")),
  ]

  private func minutes(_ s: String) -> Int {
    let p = s.split(separator: ":").compactMap { Int($0) }
    return p[0] * 60 + p[1]
  }

  private func maxError(_ c: PrayerCalc.Coordinates) -> Int {
    var worst = 0
    for (ymd, expected) in diyanet {
      let p = ymd.split(separator: "-").compactMap { Int($0) }
      let date = calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))!
      let day = PrayerCalc.day(date, at: c, calendar: calendar)!
      for key in ["imsak", "gunes", "ogle", "ikindi", "aksam", "yatsi"] {
        worst = max(worst, abs(minutes(day.times[key]!) - minutes(expected[key]!)))
      }
    }
    return worst
  }

  @Test func matchesDiyanetWithKnownCoordinates() {
    #expect(maxError(.init(lat: 41.0082, lon: 28.9784)) <= 2)
  }

  @Test func coordinatesLearnedFromDiyanetTimes() throws {
    let days = diyanet.map { PrayerDay(date: "\($0.0)T00:00:00.000Z", times: $0.1) }
    let c = try #require(PrayerCalc.fit(days, calendar: calendar))
    #expect(abs(c.lat - 41.0) < 0.5)
    #expect(abs(c.lon - 29.0) < 0.5)
    #expect(maxError(c) <= 2)
  }
}

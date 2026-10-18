import Foundation

/// Namaz kılınması mekruh olan üç kerahat vakti. RN: services/forbiddenTime.service.ts
/// 1. Güneş doğuşu: güneş vaktinden 45 dk sonrasına kadar
/// 2. İstiva (zeval): öğle vaktinden 10 dk önce başlar, öğle girince biter
/// 3. Akşam kerahati: akşam vaktinden 30 dk önce başlar, akşam girince biter
struct ForbiddenWindow: Equatable, Sendable {
  enum Kind: String, Sendable { case sunrise, zawal, sunset }

  let kind: Kind
  let start: Date
  let end: Date

  var labelKey: String { "forbidden.\(kind.rawValue).label" }
  var descriptionKey: String { "forbidden.\(kind.rawValue).description" }

  static func windows(_ times: PrayerTimes, on day: Date = Date()) -> [ForbiddenWindow] {
    let gunes = timeOn(times.gunes, day)
    let ogle = timeOn(times.ogle, day)
    let aksam = timeOn(times.aksam, day)
    return [
      ForbiddenWindow(kind: .sunrise, start: gunes, end: gunes.addingTimeInterval(45 * 60)),
      ForbiddenWindow(kind: .zawal, start: ogle.addingTimeInterval(-10 * 60), end: ogle),
      ForbiddenWindow(kind: .sunset, start: aksam.addingTimeInterval(-30 * 60), end: aksam),
    ]
  }

  static func active(_ times: PrayerTimes, now: Date = Date()) -> ForbiddenWindow? {
    windows(times, on: now).first { now >= $0.start && now < $0.end }
  }
}

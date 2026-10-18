import Foundation

/// RN qibla.service.ts ile aynı Kâbe koordinatları ve başlangıç doğrultusu.
enum QiblaMath {
  static let latitude = 21.422487
  static let longitude = 39.826206

  static func bearing(latitude startLat: Double, longitude startLng: Double) -> Double? {
    guard startLat.isFinite, startLng.isFinite, (-90...90).contains(startLat), (-180...180).contains(startLng) else { return nil }
    let lat1 = startLat * .pi / 180, lat2 = latitude * .pi / 180
    let delta = (longitude - startLng) * .pi / 180
    let y = sin(delta) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(delta)
    // Aynı noktada (ve tam antipodunda) belirli bir doğrultu yoktur.
    guard hypot(x, y) > 1e-12 else { return nil }
    return normalize(atan2(y, x) * 180 / .pi)
  }

  static func normalize(_ degrees: Double) -> Double {
    (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
  }

  /// Pozitif = fiziksel olarak sağa dön. Dil/RTL bu yönü değiştirmez.
  static func delta(bearing: Double, heading: Double) -> Double {
    let angle = normalize(bearing - heading)
    return angle > 180 ? angle - 360 : angle
  }

  /// Kuzey sınırında ve birden fazla tam turda en kısa yoldan yumuşatır.
  static func smooth(previous: Double, next: Double) -> Double {
    previous + delta(bearing: next, heading: previous) * 0.15
  }

  static func heading(trueHeading: Double, magneticHeading: Double, accuracy: Double) -> Double? {
    guard accuracy.isFinite, accuracy >= 0 else { return nil }
    if trueHeading.isFinite, trueHeading >= 0 { return normalize(trueHeading) }
    if magneticHeading.isFinite, magneticHeading >= 0 { return normalize(magneticHeading) }
    return nil
  }

  struct Alignment: Equatable {
    let delta: Double
    var aligned: Bool { abs(delta) < 5 }
    var closeness: Double { max(0, min(1, 1 - abs(delta) / 45)) }
    var zone: Int { abs(delta) < 10 ? 2 : abs(delta) < 25 ? 1 : 0 }
  }

  struct Feedback {
    enum Event: Equatable { case selection, success }
    private var previousZone = 0
    private var wasAligned = false
    mutating func update(_ alignment: Alignment) -> [Event] {
      var events: [Event] = []
      if alignment.zone > previousZone { events.append(.selection) }
      if alignment.aligned && !wasAligned { events.append(.success) }
      previousZone = alignment.zone
      wasAligned = alignment.aligned
      return events
    }
  }
}

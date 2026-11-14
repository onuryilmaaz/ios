import Foundation

/// Elde Diyanet verisi kalmadığında (çevrimdışı, sunucuda yeni yıl yok) vakitleri cihazda hesaplar.
/// Diyanet yöntemi: sabah (imsak) 18°, yatsı 17°, ikindi gölge 1 boy; temkin: güneş -7, öğle +5, ikindi +4, akşam +7 dk.
/// Koordinat, ilçenin önbellekteki Diyanet vakitlerinden geri bulunur (öğle → boylam, gün uzunluğu → enlem);
/// Diyanet tablosuyla farkı çoğunlukla 1 dakikayı geçmez. Android PrayerCalc ile aynı.
enum PrayerCalc {
  struct Coordinates: Codable, Equatable, Sendable {
    var lat: Double
    var lon: Double
  }

  private static let rad = Double.pi / 180

  static func julian(_ y: Int, _ m: Int, _ d: Int) -> Double {
    var y = y, m = m
    if m <= 2 { y -= 1; m += 12 }
    let a = y / 100, b = 2 - a + a / 4
    return Double(Int(365.25 * Double(y + 4716))) + Double(Int(30.6001 * Double(m + 1))) + Double(d + b) - 1524.5
  }

  /// Güneşin sapma açısı (derece) ve zaman denklemi (saat).
  static func sun(_ jd: Double) -> (declination: Double, equation: Double) {
    let n = jd - 2451545.0
    let g = (357.529 + 0.98560028 * n).truncatingRemainder(dividingBy: 360)
    let q = (280.459 + 0.98564736 * n).truncatingRemainder(dividingBy: 360)
    let l = (q + 1.915 * sin(g * rad) + 0.020 * sin(2 * g * rad)).truncatingRemainder(dividingBy: 360)
    let e = 23.439 - 0.00000036 * n
    var ra = atan2(cos(e * rad) * sin(l * rad), cos(l * rad)) / rad / 15
    ra = ra.truncatingRemainder(dividingBy: 24)
    if ra < 0 { ra += 24 }
    let dec = asin(sin(e * rad) * sin(l * rad)) / rad
    var eqt = q / 15 - ra
    if eqt > 12 { eqt -= 24 }
    if eqt < -12 { eqt += 24 }
    return (dec, eqt)
  }

  /// Verilen gün için vakitler (yerel saat, saat cinsinden). `tz`: o günün UTC farkı (saat).
  static func hours(year: Int, month: Int, day: Int, at c: Coordinates, tz: Double) -> [String: Double]? {
    let (dec, eqt) = sun(julian(year, month, day) - c.lon / 360 + 0.5)
    let noon = 12 + tz - c.lon / 15 - eqt
    func hourAngle(below angle: Double) -> Double? {
      let cosH = (sin(-angle * rad) - sin(c.lat * rad) * sin(dec * rad)) / (cos(c.lat * rad) * cos(dec * rad))
      guard cosH >= -1, cosH <= 1 else { return nil }
      return acos(cosH) / rad / 15
    }
    let asrAltitude = atan(1 / (1 + tan(abs(c.lat - dec) * rad))) / rad
    guard let fajr = hourAngle(below: 18), let rise = hourAngle(below: 0.833), let isha = hourAngle(below: 17),
      let asr = hourAngle(below: -asrAltitude)
    else { return nil }
    return [
      "imsak": noon - fajr, "gunes": noon - rise - 7.0 / 60, "ogle": noon + 5.0 / 60,
      "ikindi": noon + asr + 4.0 / 60, "aksam": noon + rise + 7.0 / 60, "yatsi": noon + isha,
    ]
  }

  static func clock(_ hours: Double) -> String {
    let minutes = Int((hours * 60).rounded())
    let wrapped = ((minutes % 1440) + 1440) % 1440
    return String(format: "%02d:%02d", wrapped / 60, wrapped % 60)
  }

  /// Hesaplanmış gün (Diyanet biçiminde; Hicri tarih yok).
  static func day(_ date: Date, at c: Coordinates, calendar: Calendar = .current) -> PrayerDay? {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    guard let y = parts.year, let m = parts.month, let d = parts.day else { return nil }
    let tz = Double((calendar.timeZone).secondsFromGMT(for: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date)) / 3600
    guard let h = hours(year: y, month: m, day: d, at: c, tz: tz) else { return nil }
    let times = PrayerTimes(imsak: clock(h["imsak"]!), gunes: clock(h["gunes"]!), ogle: clock(h["ogle"]!),
      ikindi: clock(h["ikindi"]!), aksam: clock(h["aksam"]!), yatsi: clock(h["yatsi"]!))
    return PrayerDay(date: String(format: "%04d-%02d-%02dT00:00:00.000Z", y, m, d), times: times)
  }

  /// Diyanet vakitlerinden koordinat: boylam her günün öğlesinden, enlem güneşin sapması büyük günlerin gün uzunluğundan.
  static func fit(_ days: [PrayerDay], calendar: Calendar = .current) -> Coordinates? {
    func minutes(_ s: String) -> Double? {
      let p = s.split(separator: ":").compactMap { Double($0) }
      return p.count == 2 ? (p[0] * 60 + p[1]) / 60 : nil
    }
    var lons: [Double] = [], lats: [Double] = []
    for day in days {
      guard let base = NotificationPlan.parseDay(day.date, calendar: calendar),
        let ogle = minutes(day.times.ogle), let rise = minutes(day.times.gunes), let set = minutes(day.times.aksam)
      else { continue }
      let parts = calendar.dateComponents([.year, .month, .day], from: base)
      guard let y = parts.year, let m = parts.month, let d = parts.day else { continue }
      let tz = Double(calendar.timeZone.secondsFromGMT(for: base.addingTimeInterval(12 * 3600))) / 3600
      let transit = ogle - 5.0 / 60
      var lon = 0.0, dec = 0.0
      for _ in 0..<3 {
        let s = sun(julian(y, m, d) - lon / 360 + 0.5)
        dec = s.declination
        lon = 15 * (12 + tz - s.equation - transit)
      }
      lons.append(lon)
      guard abs(dec) > 10 else { continue }
      let halfDay = ((set - 7.0 / 60) - (rise + 7.0 / 60)) / 2 * 15
      func f(_ lat: Double) -> Double {
        (sin(-0.833 * rad) - sin(lat * rad) * sin(dec * rad)) / (cos(lat * rad) * cos(dec * rad)) - cos(halfDay * rad)
      }
      var lo = -65.0, hi = 65.0
      guard (f(lo) > 0) != (f(hi) > 0) else { continue }
      for _ in 0..<60 {
        let mid = (lo + hi) / 2
        if (f(lo) > 0) == (f(mid) > 0) { lo = mid } else { hi = mid }
      }
      lats.append((lo + hi) / 2)
    }
    guard !lons.isEmpty, !lats.isEmpty else { return nil }
    return Coordinates(lat: lats.reduce(0, +) / Double(lats.count), lon: lons.reduce(0, +) / Double(lons.count))
  }
}

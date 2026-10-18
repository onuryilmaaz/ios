import Foundation

/// Gösterilecek vakit penceresi. RN'deki services/prayerWindow.ts ve widget'taki
/// `computePrayerWindow` (SharedData.swift) ile AYNI kurallar:
///
/// - İmsak–Güneş: Sabah vakti (çıkmasına)
/// - Güneş–Öğle: namaz vakti yok → Öğle vaktine (girmesine)
/// - Öğle→İkindi→Akşam→Yatsı: o anki vakit (çıkmasına)
/// - Yatsı–ertesi İmsak: Yatsı vakti (gece yarısından sonra da)
///
/// O anki vakit kılınmışsa sıradaki namazın girmesine sayılır.
struct PrayerWindow: Equatable, Sendable {
  enum Mode: String, Sendable { case current, upcoming }

  /// current: vaktin içindeyiz, `end` = çıkış. upcoming: vakit girmedi, `end` = giriş.
  var mode: Mode
  /// Türkçe kimlik ("Öğle"); ekranda `prayerLabel` ile çevrilir.
  var prayerName: String
  /// current modda vaktin giriş anı, upcoming'de nil.
  var start: Date?
  var end: Date
  /// `end`'den sonra gelen vakit/sınır adı.
  var nextPrayer: String

  /// - Parameter completed: Bugün kılınanlar (backend id: fajr, dhuhr, asr, maghrib, isha).
  static func compute(_ times: PrayerTimes, completed: [String], now: Date = Date()) -> PrayerWindow {
    let imsak = timeOn(times.imsak, now)
    let gunes = timeOn(times.gunes, now)
    let ogle = timeOn(times.ogle, now)
    let ikindi = timeOn(times.ikindi, now)
    let aksam = timeOn(times.aksam, now)
    let yatsi = timeOn(times.yatsi, now)

    if now >= gunes && now < ogle {
      return PrayerWindow(mode: .upcoming, prayerName: "Öğle", start: nil, end: ogle, nextPrayer: "İkindi")
    }

    let w: (id: String, name: String, start: Date, end: Date, next: String)
    if now < imsak {
      w = ("isha", "Yatsı", timeOn(times.yatsi, now, dayOffset: -1), imsak, "Sabah")
    } else if now < gunes {
      w = ("fajr", "Sabah", imsak, gunes, "Güneş")
    } else if now < ikindi {
      w = ("dhuhr", "Öğle", ogle, ikindi, "İkindi")
    } else if now < aksam {
      w = ("asr", "İkindi", ikindi, aksam, "Akşam")
    } else if now < yatsi {
      w = ("maghrib", "Akşam", aksam, yatsi, "Yatsı")
    } else {
      w = ("isha", "Yatsı", yatsi, timeOn(times.imsak, now, dayOffset: 1), "Sabah")
    }

    if completed.contains(w.id) {
      // Kılındı: sıradaki NAMAZA say (Sabah'tan sonra Güneş atlanır, Öğle'ye sayılır).
      let next: (String, Date, String) =
        switch w.id {
        case "fajr": ("Öğle", ogle, "İkindi")
        case "dhuhr": ("İkindi", ikindi, "Akşam")
        case "asr": ("Akşam", aksam, "Yatsı")
        case "maghrib": ("Yatsı", yatsi, "Sabah")
        default: ("Sabah", w.end, "Güneş")
        }
      return PrayerWindow(mode: .upcoming, prayerName: next.0, start: nil, end: next.1, nextPrayer: next.2)
    }

    return PrayerWindow(mode: .current, prayerName: w.name, start: w.start, end: w.end, nextPrayer: w.next)
  }
}

extension PrayerWindow {
  /// Şu andan itibaren `horizon` içindeki vakit geçişleri: geçiş anı ve o andan sonraki pencere.
  /// Sunucu bunları Live Activity'ye push ile gönderir. Kılınan namazlar yalnız o namaz gününün
  /// (ertesi imsaka kadar) pencerelerini etkiler. RN: services/prayerWindow.ts `buildPrayerTimeline`.
  static func timeline(_ times: PrayerTimes, completed: [String], now: Date = Date(), horizon: TimeInterval = 8 * 3600) -> [(at: Date, window: PrayerWindow)] {
    var out: [(Date, PrayerWindow)] = []
    let limit = now.addingTimeInterval(horizon)
    // Bugünün namaz günü ertesi imsakta biter (gece yarısından önceyse yarın).
    let imsakToday = timeOn(times.imsak, now)
    let dayEnd = now < imsakToday ? imsakToday : timeOn(times.imsak, now, dayOffset: 1)

    var w = compute(times, completed: completed, now: now)
    for _ in 0..<12 where w.end <= limit {
      let t = w.end.addingTimeInterval(1)
      let next = compute(times, completed: t < dayEnd ? completed : [], now: t)
      guard next.end > w.end else { break }  // güvenlik: ilerlemiyorsa dur
      out.append((w.end, next))
      w = next
    }
    return out
  }
}

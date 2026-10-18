import Foundation

// SharedData.swift yalnız Foundation'a bağlı kalsın diye (uygulama hedefinde de
// derleniyor: alarmdaki "Kıldım" MarkPrayerIntent'i kullanır) WL'ye bağlı vakit
// penceresi hesabı burada.

// MARK: - Prayer Window (o anki vakit / sıradaki vakit)

enum PrayerWindowMode {
  /// İçinde bulunulan vakit gösterilir; sayaç vaktin ÇIKMASINA sayar.
  case current
  /// Aktif vakit yok (Güneş–Öğle arası) ya da o anki vakit kılınmış:
  /// sıradaki vakit gösterilir, sayaç vaktin GİRMESİNE sayar.
  case upcoming
}

struct PrayerWindowState {
  let mode: PrayerWindowMode
  let prayerName: String   // "Öğle"
  let startDate: Date?     // current modda vaktin giriş anı (ilerleme için)
  let endDate: Date        // current: çıkış anı, upcoming: giriş anı
  let endTime: String      // endDate'in "HH:mm" hali
  let nextPrayer: String   // endDate'ten sonra gelen vakit/sınır adı

  /// Sayacın üstündeki tek cümle (uygulamadaki ana sayfa ile aynı):
  /// "İkindi vaktinin çıkmasına" / "Öğle vaktine". Altına ayrıca açıklama yazılmaz.
  var headline: String {
    mode == .current
      ? WL.t("window.untilEnd", WL.prayer(prayerName)) : WL.t("window.until", WL.prayer(prayerName))
  }
  /// Alt bilgi: o anki vakitte çıkış (= sıradaki vaktin girişi), aksi halde giriş saati.
  var footnote: String { mode == .current ? WL.t("window.ends", endTime) : WL.t("window.starts", endTime) }
  var key: String { prayerKeyFromName(prayerName) }

  /// Vaktin ne kadarı geçti (0…1). Sıradaki vakte sayılırken giriş bilinmez → nil.
  func progress(at now: Date) -> Double? {
    guard let start = startDate else { return nil }
    let total = endDate.timeIntervalSince(start)
    guard total > 0 else { return nil }
    return min(1, max(0, now.timeIntervalSince(start) / total))
  }
}

/// Vakit penceresi kuralları:
/// - İmsak–Güneş: Sabah vakti (çıkmasına)
/// - Güneş–Öğle: namaz vakti yok → Öğle vaktine (girmesine)
/// - Öğle→İkindi→Akşam→Yatsı: o anki vakit (çıkmasına)
/// - Yatsı–ertesi İmsak: Yatsı vakti (gece yarısından sonra da)
/// O anki vakit kılınmışsa aciliyet kalmaz; sıradaki namazın girmesine sayılır.
func computePrayerWindow(data: WidgetData?, completed: [String], at now: Date) -> PrayerWindowState? {
  guard let data = data else { return nil }
  let cal = Calendar.current

  func toDate(_ timeStr: String, dayOffset: Int = 0) -> Date? {
    let parts = timeStr.split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2, let day = cal.date(byAdding: .day, value: dayOffset, to: now) else { return nil }
    var c = cal.dateComponents([.year, .month, .day], from: day)
    c.hour = parts[0]; c.minute = parts[1]; c.second = 0
    return cal.date(from: c)
  }

  guard
    let imsak = toDate(data.imsak), let gunes = toDate(data.gunes),
    let ogle = toDate(data.ogle), let ikindi = toDate(data.ikindi),
    let aksam = toDate(data.aksam), let yatsi = toDate(data.yatsi),
    let tomorrowImsak = toDate(data.imsak, dayOffset: 1),
    let yesterdayYatsi = toDate(data.yatsi, dayOffset: -1)
  else { return nil }

  func hhmm(_ d: Date) -> String {
    let c = cal.dateComponents([.hour, .minute], from: d)
    return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
  }

  // (widget id, ad, giriş, çıkış, çıkıştan sonraki ad)
  let window: (id: String, name: String, start: Date, end: Date, next: String)
  if now < imsak {
    window = ("yatsi", "Yatsı", yesterdayYatsi, imsak, "Sabah")
  } else if now < gunes {
    window = ("sabah", "Sabah", imsak, gunes, "Güneş")
  } else if now < ogle {
    return PrayerWindowState(
      mode: .upcoming, prayerName: "Öğle", startDate: nil,
      endDate: ogle, endTime: hhmm(ogle), nextPrayer: "İkindi")
  } else if now < ikindi {
    window = ("ogle", "Öğle", ogle, ikindi, "İkindi")
  } else if now < aksam {
    window = ("ikindi", "İkindi", ikindi, aksam, "Akşam")
  } else if now < yatsi {
    window = ("aksam", "Akşam", aksam, yatsi, "Yatsı")
  } else {
    window = ("yatsi", "Yatsı", yatsi, tomorrowImsak, "Sabah")
  }

  if isPrayerCompleted(window.id, in: completed) {
    // Kılındı: sıradaki NAMAZA say (Sabah'tan sonra Güneş atlanır, Öğle'ye sayılır).
    let upcoming: (name: String, at: Date, next: String)
    switch window.id {
    case "sabah":  upcoming = ("Öğle", ogle, "İkindi")
    case "ogle":   upcoming = ("İkindi", ikindi, "Akşam")
    case "ikindi": upcoming = ("Akşam", aksam, "Yatsı")
    case "aksam":  upcoming = ("Yatsı", yatsi, "Sabah")
    default:       upcoming = ("Sabah", window.end, "Güneş")
    }
    return PrayerWindowState(
      mode: .upcoming, prayerName: upcoming.name, startDate: nil,
      endDate: upcoming.at, endTime: hhmm(upcoming.at), nextPrayer: upcoming.next)
  }

  return PrayerWindowState(
    mode: .current, prayerName: window.name, startDate: window.start,
    endDate: window.end, endTime: hhmm(window.end), nextPrayer: window.next)
}

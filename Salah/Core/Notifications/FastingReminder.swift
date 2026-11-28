import Foundation

/// Nafile oruç hatırlatıcısının gün grupları (ayarlarda çoklu seçim).
enum FastingGroup: String, CaseIterable, Hashable, Sendable {
  /// Pazartesi ve perşembe.
  case weekly
  /// Eyyâm-ı bîz: Hicri ayın 13, 14, 15'i.
  case ayyamBid
  /// Aşure: Muharrem 9 ve 10.
  case ashura
  /// Arefe: Zilhicce 9.
  case arafah

  var labelKey: String {
    switch self {
    case .weekly: "nafile.weekly"
    case .ayyamBid: "nafile.ayyamBid"
    case .ashura: "nafile.ashura"
    case .arafah: "nafile.arafah"
    }
  }
}

/// Bir güne düşen tek tür. Çakışmada öncelik: Arefe > Aşure > Eyyâm-ı bîz > Pazartesi/Perşembe.
enum FastingKind: String, Sendable {
  case arafah, ashura, ayyamBid, monday, thursday

  var notificationKey: String {
    switch self {
    case .arafah: "nafile.notifArafah"
    case .ashura: "nafile.notifAshura"
    case .ayyamBid: "nafile.notifAyyamBid"
    case .monday: "nafile.notifMonday"
    case .thursday: "nafile.notifThursday"
    }
  }
}

struct FastingDay: Equatable, Sendable {
  var date: Date
  var kind: FastingKind
}

enum FastingReminder {
  /// Hatırlatma asla yapılmayan günler: Ramazan'ın tamamı, 1 Şevval, 10-13 Zilhicce.
  static func isExcluded(_ h: HijriDate) -> Bool {
    h.month == 9 || (h.month == 10 && h.day == 1) || (h.month == 12 && (10...13).contains(h.day))
  }

  /// `from` gününden başlayan `days` gün içindeki nafile oruç günleri (gün başı tarihleriyle, sıralı).
  /// `hijri`: uygulamanın takvim ekranındaki Hicri hesap (`ReligiousCalendar.hijri`).
  static func fastingDays(from: Date, days: Int, hijri: (Date) -> HijriDate, enabled: Set<FastingGroup>,
                          calendar: Calendar = .current) -> [FastingDay] {
    guard days > 0, !enabled.isEmpty else { return [] }
    let start = calendar.startOfDay(for: from)
    var result: [FastingDay] = []
    for delta in 0..<days {
      guard let day = calendar.date(byAdding: .day, value: delta, to: start) else { continue }
      let h = hijri(day)
      guard !isExcluded(h) else { continue }
      let weekday = calendar.component(.weekday, from: day)
      let kind: FastingKind?
      if enabled.contains(.arafah), h.month == 12, h.day == 9 { kind = .arafah }
      else if enabled.contains(.ashura), h.month == 1, h.day == 9 || h.day == 10 { kind = .ashura }
      else if enabled.contains(.ayyamBid), (13...15).contains(h.day) { kind = .ayyamBid }
      else if enabled.contains(.weekly), weekday == 2 { kind = .monday }
      else if enabled.contains(.weekly), weekday == 5 { kind = .thursday }
      else { kind = nil }
      if let kind { result.append(FastingDay(date: day, kind: kind)) }
    }
    return result
  }

  static let eveHour = 21
  static let suhoorLead: TimeInterval = 45 * 60
}

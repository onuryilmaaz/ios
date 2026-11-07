import CoreGraphics
import Foundation

/// Bir Ramazan ayının gün aralığı (Diyanet takvimi, yoksa aynı hesapla tahmin).
struct RamadanWindow: Equatable, Sendable {
  var hijriYear: Int
  /// İlk günün gece yarısı.
  var start: Date
  /// Son günün gece yarısı (bayramdan önceki gün).
  var last: Date
  var days: Int
}

enum RamadanPhase: Equatable, Sendable {
  case none
  case upcoming(daysLeft: Int, start: Date)
  case active(day: Int, total: Int, countdown: RamadanCountdown?)
}

struct RamadanCountdown: Equatable, Sendable {
  enum Kind: String, Sendable { case iftar, sahur }
  var kind: Kind
  var target: Date
}

/// Saf Ramazan hesapları: saat, takvim ve vakitler dışarıdan verilir.
enum RamadanPlan {
  /// Kart, Ramazan'dan bu kadar gün önce görünmeye başlar.
  static let lookaheadDays = 30
  /// Önizleme penceresinin yılı: oruçları gerçek yıllardan ayrı durur, sunucuya gitmez, imsakiyesi saklanmaz.
  static let previewHijriYear = 9999

  /// Ayar: nil ise takvime göre (Ramazan'dan 30 gün önce başlar, bitince kapanır), yoksa kullanıcının seçimi.
  static func isModeOn(stored: Bool?, real: RamadanWindow, now: Date, calendar: Calendar) -> Bool {
    stored ?? (phase(real, now: now, today: nil, tomorrow: nil, calendar: calendar) != .none)
  }

  /// Kullanıcı açtı ama takvimde Ramazan yok: özellikler örnek pencereyle görünür.
  static func usesPreview(stored: Bool?, real: RamadanWindow, now: Date, calendar: Calendar) -> Bool {
    stored == true && phase(real, now: now, today: nil, tomorrow: nil, calendar: calendar) == .none
  }

  /// Kadir Gecesi: 26. günün akşamı (27. gece). Bugünse 0, geçtiyse nil.
  static func kadirDaysLeft(_ window: RamadanWindow, now: Date, calendar: Calendar) -> Int? {
    guard let night = calendar.date(byAdding: .day, value: 25, to: window.start) else { return nil }
    let left = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: night).day ?? -1
    return left >= 0 ? left : nil
  }

  /// İftar anı ekranı: Ramazan gününde, akşam vakti girdikten sonra günde bir kez.
  static func iftarMomentDue(_ window: RamadanWindow, now: Date, today: PrayerTimes?, shownDay: String?, calendar: Calendar) -> Bool {
    let day = calendar.startOfDay(for: now)
    guard day >= window.start, day <= window.last, shownDay != dayString(day, calendar),
      let aksam = clock(today?["aksam"], on: day, calendar) else { return false }
    return now >= aksam
  }

  private static func dayString(_ day: Date, _ calendar: Calendar) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: day)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  /// Bugün 5. gün olan 29 günlük örnek Ramazan.
  static func previewWindow(now: Date, calendar: Calendar) -> RamadanWindow {
    let start = calendar.date(byAdding: .day, value: -4, to: calendar.startOfDay(for: now)) ?? now
    return .init(hijriYear: previewHijriYear, start: start, last: calendar.date(byAdding: .day, value: 28, to: start) ?? start, days: 29)
  }

  static func window(_ religious: ReligiousCalendar, now: Date, calendar: Calendar) -> RamadanWindow {
    let today = calendar.startOfDay(for: now)
    let year = religious.hijri(now).year
    let current = make(religious, year: year, calendar: calendar)
    return today > current.last ? make(religious, year: year + 1, calendar: calendar) : current
  }

  private static func make(_ religious: ReligiousCalendar, year: Int, calendar: Calendar) -> RamadanWindow {
    let start = calendar.startOfDay(for: religious.date(year: year, month: 9, day: 1))
    let bayram = calendar.startOfDay(for: religious.date(year: year, month: 10, day: 1))
    let last = calendar.date(byAdding: .day, value: -1, to: bayram) ?? bayram
    let days = (calendar.dateComponents([.day], from: start, to: last).day ?? 28) + 1
    return .init(hijriYear: year, start: start, last: last, days: days)
  }

  /// Geri sayım: imsaka kadar sahur, akşama kadar iftar, akşamdan sonra yarının sahuru. Son günün iftarından sonra Ramazan biter.
  static func phase(_ window: RamadanWindow, now: Date, today: PrayerTimes?, tomorrow: PrayerTimes?, calendar: Calendar) -> RamadanPhase {
    let day = calendar.startOfDay(for: now)
    if day < window.start {
      let left = calendar.dateComponents([.day], from: day, to: window.start).day ?? .max
      return left <= lookaheadDays ? .upcoming(daysLeft: left, start: window.start) : .none
    }
    if day > window.last { return .none }
    let number = (calendar.dateComponents([.day], from: window.start, to: day).day ?? 0) + 1
    guard let today, let imsak = clock(today["imsak"], on: day, calendar), let aksam = clock(today["aksam"], on: day, calendar) else {
      return .active(day: number, total: window.days, countdown: nil)
    }
    if now < imsak { return .active(day: number, total: window.days, countdown: .init(kind: .sahur, target: imsak)) }
    if now < aksam { return .active(day: number, total: window.days, countdown: .init(kind: .iftar, target: aksam)) }
    if day == window.last { return .none }
    let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
    let sahur = tomorrow.flatMap { clock($0["imsak"], on: next, calendar) }
    return .active(day: number, total: window.days, countdown: sahur.map { .init(kind: .sahur, target: $0) })
  }

  /// Yıllık vakitlerden bu Ramazan'ın günleri. Takvim tahmininden birkaç gün sapabilir; asıl ölçüt kaydın kendi Hicri ayı.
  static func imsakiye(_ days: [PrayerDay], window: RamadanWindow, calendar: Calendar) -> [PrayerDay] {
    let margin = window.hijriYear == previewHijriYear ? 0 : 3
    let from = calendar.date(byAdding: .day, value: -margin, to: window.start) ?? window.start
    let to = calendar.date(byAdding: .day, value: margin, to: window.last) ?? window.last
    return days.filter { day in
      guard window.hijriYear == previewHijriYear || day.hijri_date?.month == 9, let local = day.localDay else { return false }
      return local >= from && local <= to
    }
    .sorted { ($0.localDay ?? .distantPast) < ($1.localDay ?? .distantPast) }
  }

  private static func clock(_ raw: String?, on day: Date, _ calendar: Calendar) -> Date? {
    raw.flatMap { NotificationPlan.clock($0, on: day, calendar: calendar) }
  }
}

/// Saf hatim planı hesapları.
struct HatimPlan: Codable, Equatable, Sendable {
  /// Bitiş günü, "yyyy-MM-dd".
  var targetDate: String
  /// Plan başladığında tamamlanmış hatim sayısı: artınca plan bitmiştir.
  var startHatims: Int
  var reminderHour: Int?
  var reminderMinute: Int?

  struct Progress: Equatable, Sendable {
    var remaining: Int
    var daysLeft: Int
    var dailyTarget: Int
    var todayRead: Int
    var finished: Bool
    var overdue: Bool

    var todayDone: Bool { todayRead >= dailyTarget }
  }

  func progress(completedHatims: Int, currentPages: Int, pagesPerHatim: Int, todayRead: Int, today: Date, calendar: Calendar) -> Progress {
    let finished = completedHatims > startHatims
    let remaining = max(0, pagesPerHatim - currentPages)
    let target = Self.parse(targetDate, calendar: calendar) ?? today
    let left = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: target).day ?? 0
    return .init(
      remaining: remaining, daysLeft: max(1, left + 1),
      dailyTarget: Self.dailyPages(pages: remaining + max(0, todayRead), daysLeft: max(1, left + 1)),
      todayRead: max(0, todayRead), finished: finished, overdue: !finished && left < 0)
  }

  /// Bugün dahil kalan günlere eşit bölüşüm, yukarı yuvarlı (en az 1).
  static func dailyPages(pages: Int, daysLeft: Int) -> Int {
    max(1, Int((Double(max(0, pages)) / Double(max(1, daysLeft))).rounded(.up)))
  }

  static func parse(_ ymd: String, calendar: Calendar) -> Date? {
    let p = ymd.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return nil }
    return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
  }
}

/// Ramazan gününe göre ayın aydınlık kısmı (kart, defter aynı çizimi kullanır; widget uzantısında kopyası var).
enum RamadanMoon {
  nonisolated private static let cycle = 29.53

  /// 0...1; ilk günlerde de hilal seçilebilsin diye alt sınır var.
  nonisolated static func illumination(day: Int) -> Double {
    max(0.05, (1 - cos(2 * .pi * Double(day) / cycle)) / 2)
  }

  /// Birim çemberde (y aşağı) aydınlık bölgenin dış çizgisi. Ay büyürken sağ, küçülürken sol taraf aydınlıktır.
  nonisolated static func outline(day: Int, steps: Int = 28) -> [CGPoint] {
    let side = Double(day) / cycle < 0.5 ? 1.0 : -1.0
    let f = illumination(day: day)
    let angle = { (i: Int) in -Double.pi / 2 + .pi * Double(i) / Double(steps) }
    let outer = (0...steps).map { CGPoint(x: side * cos(angle($0)), y: sin(angle($0))) }
    let inner = (0...steps).reversed().map { CGPoint(x: side * cos(angle($0)) * (1 - 2 * f), y: sin(angle($0))) }
    return outer + inner
  }
}

/// Oruç defteri: tutulan günler, kaza sayacı ve sunucuya henüz gitmemiş değişiklikler. Yerel öncelikli: işaret hemen
/// yazılır, bekleyenler sonraki eşitlemede tek istekle gider. Sunucu yeni sürümden sonra canlıya alındığı için 404
/// dahil her hata bekleyenleri korur.
struct RamadanLedger: Codable, Equatable, Sendable {
  var fasts: [String: [String]] = [:]
  var pending: [String: [String: Bool]] = [:]
  var kaza = 0
  var kazaPending = 0

  func days(_ year: Int) -> Set<String> { Set(fasts[String(year)] ?? []) }

  func marking(_ year: Int, day: String, fasted: Bool) -> RamadanLedger {
    var next = self
    var set = days(year)
    if fasted { set.insert(day) } else { set.remove(day) }
    next.fasts[String(year)] = set.sorted()
    if year != RamadanPlan.previewHijriYear { next.pending[String(year), default: [:]][day] = fasted }
    return next
  }

  func addingKaza(_ delta: Int) -> RamadanLedger {
    var next = self
    next.kaza = max(0, kaza + delta)
    next.kazaPending = kazaPending + (next.kaza - kaza)
    return next
  }

  /// Sunucu yanıtı; istek sürerken yapılan değişiklikler bekler ve görünümde korunur.
  func merged(_ year: Int, sent: [String: Bool], sentKaza: Int, serverDays: [String], serverKaza: Int) -> RamadanLedger {
    var next = self
    let key = String(year)
    let left = (pending[key] ?? [:]).filter { sent[$0.key] != $0.value }
    var shown = Set(serverDays)
    for (day, value) in left {
      if value { shown.insert(day) } else { shown.remove(day) }
    }
    next.fasts[key] = shown.sorted()
    next.pending[key] = left.isEmpty ? nil : left
    next.kazaPending = kazaPending - sentKaza
    next.kaza = max(0, serverKaza + next.kazaPending)
    return next
  }
}

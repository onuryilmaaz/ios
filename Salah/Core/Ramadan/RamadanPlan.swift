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

  /// Hilal tonu: akşamdan imsaka gece, imsaktan öğleye şafak, öğleden akşama mihrap. Vakit yoksa gece.
  static func tint(now: Date, today: PrayerTimes?, calendar: Calendar) -> RamadanTintPhase {
    let day = calendar.startOfDay(for: now)
    guard let today, let imsak = clock(today["imsak"], on: day, calendar), let ogle = clock(today["ogle"], on: day, calendar),
      let aksam = clock(today["aksam"], on: day, calendar) else { return .night }
    if now < imsak || now >= aksam { return .night }
    return now < ogle ? .dawn : .dusk
  }

  /// Ramazan gününün ayeti (sure, ayet). Metin uygulamanın Kur'an verisinden gelir.
  static let dailyVerses: [(surah: Int, verse: Int)] = [
    (2, 183), (2, 184), (2, 185), (2, 186), (3, 134), (2, 153), (2, 152), (13, 28), (3, 133), (39, 53),
    (2, 261), (3, 92), (2, 274), (57, 7), (40, 60), (3, 8), (14, 40), (33, 41), (49, 13), (44, 3),
    (66, 8), (3, 200), (39, 10), (17, 9), (54, 17), (97, 1), (97, 3), (97, 5), (38, 29), (73, 4),
  ]

  static func dailyVerse(day: Int) -> (surah: Int, verse: Int) {
    dailyVerses[min(max(day - 1, 0), dailyVerses.count - 1)]
  }

  /// Son on gün (29 ya da 30 günlük ayda).
  static func lastNights(_ window: RamadanWindow, calendar: Calendar) -> [Date] {
    (0...9).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: window.last) }
  }

  static func kadirDate(_ window: RamadanWindow, calendar: Calendar) -> Date {
    calendar.date(byAdding: .day, value: 25, to: window.start) ?? window.start
  }

  /// Geçmiş günlerden oruç işareti olmayanlar; bugün sayılmaz.
  static func unmarkedDays(_ window: RamadanWindow, now: Date, marked: Set<String>, calendar: Calendar) -> [String] {
    let today = calendar.startOfDay(for: now)
    var out: [String] = []
    var day = window.start
    while day <= window.last, day < today {
      let key = dayString(day, calendar)
      if !marked.contains(key) { out.append(key) }
      guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
      day = next
    }
    return out
  }

  struct CountdownStep: Equatable {
    var at: Date
    var kind: RamadanCountdown.Kind
    var target: Date
  }

  /// Dinamik çizelge: imsaka sahur, akşama iftar, akşamdan sonra yarının sahuru.
  static func countdownSteps(_ window: RamadanWindow, now: Date, calendar: Calendar, times: (Date) -> PrayerTimes?) -> [CountdownStep] {
    var out: [CountdownStep] = []
    var day = calendar.startOfDay(for: now)
    var at = now
    for _ in 0..<4 {
      guard day >= window.start, day <= window.last, let t = times(day),
        let imsak = clock(t["imsak"], on: day, calendar), let aksam = clock(t["aksam"], on: day, calendar) else { return out }
      if at < imsak {
        out.append(.init(at: at, kind: .sahur, target: imsak))
        at = imsak
      }
      if at < aksam {
        out.append(.init(at: at, kind: .iftar, target: aksam))
        at = aksam
      }
      guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return out }
      day = next
    }
    return out
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
  /// Hicri yıl -> tür (taraweeh, night, kaza) -> günler.
  var marks: [String: [String: [String]]] = [:]
  /// Hicri yıl -> "tür|gün" -> açık mı.
  var pendingMarks: [String: [String: Bool]] = [:]
  /// Hicri yıl -> sunucudan gelen özel gün günleri.
  var ozelGun: [String: [String]] = [:]

  init() {}

  /// Önceki sürümün kaydı yeni alanlar olmadan da açılır.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    fasts = try c.decodeIfPresent([String: [String]].self, forKey: .fasts) ?? [:]
    pending = try c.decodeIfPresent([String: [String: Bool]].self, forKey: .pending) ?? [:]
    kaza = try c.decodeIfPresent(Int.self, forKey: .kaza) ?? 0
    kazaPending = try c.decodeIfPresent(Int.self, forKey: .kazaPending) ?? 0
    marks = try c.decodeIfPresent([String: [String: [String]]].self, forKey: .marks) ?? [:]
    pendingMarks = try c.decodeIfPresent([String: [String: Bool]].self, forKey: .pendingMarks) ?? [:]
    ozelGun = try c.decodeIfPresent([String: [String]].self, forKey: .ozelGun) ?? [:]
  }

  func days(_ year: Int) -> Set<String> { Set(fasts[String(year)] ?? []) }

  func markDays(_ year: Int, kind: String) -> Set<String> { Set(marks[String(year)]?[kind] ?? []) }

  func marking(_ year: Int, day: String, fasted: Bool) -> RamadanLedger {
    var next = self
    var set = days(year)
    if fasted { set.insert(day) } else { set.remove(day) }
    next.fasts[String(year)] = set.sorted()
    if year != RamadanPlan.previewHijriYear { next.pending[String(year), default: [:]][day] = fasted }
    return next
  }

  func settingMark(_ year: Int, kind: String, day: String, on: Bool) -> RamadanLedger {
    var next = self
    var set = markDays(year, kind: kind)
    if on { set.insert(day) } else { set.remove(day) }
    next.marks[String(year), default: [:]][kind] = set.sorted()
    if year != RamadanPlan.previewHijriYear { next.pendingMarks[String(year), default: [:]]["\(kind)|\(day)"] = on }
    return next
  }

  func addingKaza(_ delta: Int) -> RamadanLedger {
    var next = self
    next.kaza = max(0, kaza + delta)
    next.kazaPending = kazaPending + (next.kaza - kaza)
    return next
  }

  /// Tutulmayan günleri bir kez kazaya aktarır; aynı gün iki kez sayılmaz. Önizlemede sunucuya gitmez.
  func applyingKaza(_ year: Int, days: [String]) -> RamadanLedger {
    let done = markDays(year, kind: "kaza")
    let fresh = days.filter { !done.contains($0) }
    guard !fresh.isEmpty else { return self }
    var next = self
    for day in fresh { next = next.settingMark(year, kind: "kaza", day: day, on: true) }
    if year == RamadanPlan.previewHijriYear {
      next.kaza += fresh.count
      return next
    }
    return next.addingKaza(fresh.count)
  }

  /// Sunucu yanıtı; istek sürerken yapılan değişiklikler bekler ve görünümde korunur.
  /// `serverMarks` nil ise (eski sunucu) işaretler bekler, kaybolmaz.
  func merged(
    _ year: Int, sent: [String: Bool], sentKaza: Int, serverDays: [String], serverKaza: Int,
    sentMarks: [String: Bool] = [:], serverMarks: [String: [String]]? = nil, serverOzelGun: [String]? = nil
  ) -> RamadanLedger {
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
    if let serverMarks {
      let leftMarks = (pendingMarks[key] ?? [:]).filter { sentMarks[$0.key] != $0.value }
      var shownMarks = serverMarks.mapValues { Set($0) }
      for (id, value) in leftMarks {
        let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { continue }
        if value { shownMarks[parts[0], default: []].insert(parts[1]) } else { shownMarks[parts[0], default: []].remove(parts[1]) }
      }
      next.marks[key] = shownMarks.mapValues { $0.sorted() }
      next.pendingMarks[key] = leftMarks.isEmpty ? nil : leftMarks
    }
    if let serverOzelGun { next.ozelGun[key] = serverOzelGun }
    return next
  }
}

enum RamadanTintPhase: String, Sendable { case night, dawn, dusk }

/// Diyanet ölçüleriyle zekât: nisap 80,18 gram altın değeri, oran kırkta bir.
enum ZakatCalc {
  struct Result: Equatable {
    var net: Double
    var nisab: Double
    var due: Bool
    var amount: Double
  }

  /// Klavye diline bakmadan okur: "1.250" ve "1,250" bin ayraçlıdır (gram için ondalık), "1.250,50" = 1250,5.
  static func parseAmount(_ text: String, grouped: Bool = true) -> Double {
    var s = ""
    for scalar in text.unicodeScalars {
      switch scalar.value {
      case 0x0660...0x0669: s.unicodeScalars.append(Unicode.Scalar(scalar.value - 0x0660 + 48)!)
      case 0x06F0...0x06F9: s.unicodeScalars.append(Unicode.Scalar(scalar.value - 0x06F0 + 48)!)
      case 0x066B: s.append(",")
      case 0x066C: s.append(".")
      case 48...57, 44, 46: s.unicodeScalars.append(scalar)
      default: break
      }
    }
    let dots = s.filter { $0 == "." }.count
    let commas = s.filter { $0 == "," }.count
    if dots > 0, commas > 0, let lastDot = s.lastIndex(of: "."), let lastComma = s.lastIndex(of: ",") {
      let decimal: Character = lastDot > lastComma ? "." : ","
      let group: Character = decimal == "." ? "," : "."
      s = s.filter { $0 != group }.map { $0 == decimal ? "." : String($0) }.joined()
    } else if dots + commas > 1 {
      s = s.filter { $0 != "." && $0 != "," }
    } else if dots + commas == 1 {
      let parts = s.split(separator: dots == 1 ? "." : ",", omittingEmptySubsequences: false)
      let thousands = grouped && parts[1].count == 3 && (1...3).contains(parts[0].count) && !parts[0].hasPrefix("0")
      s = thousands ? parts.joined() : parts.joined(separator: ".")
    }
    return Double(s) ?? 0
  }

  static func compute(goldGrams: Double, goldPrice: Double, cash: Double, trade: Double, receivable: Double, debt: Double, nisabGrams: Double = 80.18) -> Result {
    let price = max(0, goldPrice)
    let net = max(0, goldGrams) * price + max(0, cash) + max(0, trade) + max(0, receivable) - max(0, debt)
    let nisab = nisabGrams * price
    let due = nisab > 0 && net >= nisab
    return Result(net: net, nisab: nisab, due: due, amount: due ? net / 40 : 0)
  }
}

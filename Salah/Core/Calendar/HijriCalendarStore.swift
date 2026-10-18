import Foundation

struct HijriMonth: Equatable {
  var year: Int
  var month: Int

  init(year: Int, month: Int) {
    self.year = year + Int(floor(Double(month - 1) / 12))
    self.month = ((month - 1) % 12 + 12) % 12 + 1
  }
  init(_ date: HijriDate) { self.init(year: date.year, month: date.month) }
  func shifted(_ months: Int) -> Self { .init(year: year, month: month + months) }
}

/// Pazartesi başlayan 7 sütun; hücre/satır kimlikleri dil ve tema değişiminde sabit.
struct HijriMonthGrid {
  let month: HijriMonth
  let start: Date
  let dayCount: Int
  let firstWeekday: Int
  let cells: [Int?]
  private let calendar: ReligiousCalendar

  init(month: HijriMonth, calendar: ReligiousCalendar) {
    self.month = month
    self.calendar = calendar
    start = calendar.date(year: month.year, month: month.month, day: 1)
    let next = month.shifted(1)
    let end = calendar.date(year: next.year, month: next.month, day: 1)
    // Saat farkı yerine takvim günü: yaz/kış saati 23/25 saatlik gün üretir.
    let length = HijriMath.julian(date: end, calendar: calendar.calendar) - HijriMath.julian(date: start, calendar: calendar.calendar)
    dayCount = min(31, max(1, length))
    firstWeekday = (calendar.calendar.component(.weekday, from: start) + 5) % 7
    var values: [Int?] = Array(repeating: nil, count: firstWeekday) + (1...dayCount).map { Optional($0) }
    while values.count % 7 != 0 { values.append(nil) }
    cells = values
  }
  func date(_ day: Int) -> Date { calendar.date(year: month.year, month: month.month, day: day) }
  func events(_ days: [ReligiousDay]) -> [Int: ReligiousDay] {
    var byDate: [Int: ReligiousDay] = [:]
    for day in days { byDate[HijriMath.julian(date: day.date, calendar: calendar.calendar)] = day }
    var result: [Int: ReligiousDay] = [:]
    for day in 1...dayCount { result[day] = byDate[HijriMath.julian(date: date(day), calendar: calendar.calendar)] }
    return result
  }
}

enum HijriCalendarText {
  static func monthName(_ month: Int) -> String {
    let names = Localizer.shared.list("hijri.months")
    return names.indices.contains(month - 1) ? names[month - 1] : ""
  }
  static func hijri(_ date: HijriDate) -> String { "\(date.day) \(monthName(date.month)) \(date.year)" }
  static func gregorian(_ date: Date, template: String, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.locale = Localizer.shared.locale
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: date)
  }
  static func daysLeft(until date: Date, now: Date, calendar: Calendar) -> Int {
    calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
  }
}

@Observable
final class HijriCalendarStore {
  static let shared: HijriCalendarStore = {
    #if DEBUG
    if let mode = DebugLaunch.calendar {
      let cal = HijriMath.gregorianCalendar
      let date = cal.date(from: DateComponents(year: 2026, month: 2, day: 19, hour: 12))!
      // Mevcut açık yıllık API'den alınan gerçek 2026 verisi; Release'e girmez.
      let source = ReligiousCalendar(cache: HijriCalendarPreview.cache, calendar: cal)
      let store = HijriCalendarStore(initial: source, now: { date }, load: { _ in source })
      if mode == "next" { store.move(1) }
      if mode == "past" { store.move(-1) }
      if mode == "yearEnd" { store.move(3) }
      return store
    }
    #endif
    return HijriCalendarStore()
  }()

  private(set) var calendar: ReligiousCalendar
  private(set) var now: Date
  private(set) var viewMonth: HijriMonth
  @ObservationIgnored private let clock: () -> Date
  @ObservationIgnored private let load: (Date) async -> ReligiousCalendar
  @ObservationIgnored private var generation = 0

  init(initial: ReligiousCalendar = ReligiousCalendarService.cached(), now: @escaping () -> Date = { Date() },
    load: @escaping (Date) async -> ReligiousCalendar = { await ReligiousCalendarService.load(now: $0) }) {
    let date = now()
    calendar = initial
    self.now = date
    viewMonth = HijriMonth(initial.hijri(date))
    clock = now
    self.load = load
  }

  var today: HijriDate { calendar.hijri(now) }
  var isViewingToday: Bool { viewMonth == HijriMonth(today) }
  var grid: HijriMonthGrid { .init(month: viewMonth, calendar: calendar) }
  var religiousDays: [ReligiousDay] { calendar.religiousDays(now: now) }
  var upcoming: [ReligiousDay] {
    Array(religiousDays.filter { $0.date >= calendar.calendar.startOfDay(for: now) }.prefix(6))
  }
  func move(_ months: Int) {
    let next = viewMonth.shifted(months)
    guard (1...9998).contains(next.year) else { return }
    viewMonth = next
  }
  func goToday() { viewMonth = HijriMonth(today) }

  func updateClock() {
    let wasToday = isViewingToday
    now = clock()
    if wasToday { goToday() }
  }
  func refresh() async {
    updateClock()
    generation += 1
    let version = generation, requestedMonth = viewMonth, wasToday = isViewingToday
    let fresh = await load(now)
    guard !Task.isCancelled, generation == version else { return }
    calendar = fresh
    // Ağ yanıtı kullanıcı ay değiştirirken gelirse seçimini geri alma.
    if wasToday && viewMonth == requestedMonth { goToday() }
  }
}

#if DEBUG
private enum HijriCalendarPreview {
  static let cache: ReligiousCalendar.Cache? = {
    guard let url = Bundle.main.url(forResource: "HijriCalendarPreview", withExtension: "json"),
      let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(ReligiousCalendar.Cache.self, from: data)
  }()
}
#endif

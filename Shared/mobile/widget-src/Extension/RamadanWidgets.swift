import AppIntents
import SwiftUI
import WidgetKit

// Oruç ve imsakiye widget'ları. Uygulama `salah_ramadan_data` yazar (WidgetBridge.updateRamadan); vakitler
// `salah_widget_data` günlerinden gelir, böylece uygulama günlerce açılmasa da doğru gün çizilir.

struct RamadanData: Codable {
  var on: Bool
  var hijriYear: Int
  var start: String
  var last: String
  var total: Int
  var fasted: [String]

  static func load() -> RamadanData? {
    guard let raw = UserDefaults(suiteName: appGroupID)?.data(forKey: "salah_ramadan_data") else { return nil }
    return try? JSONDecoder().decode(RamadanData.self, from: raw)
  }
}

struct RamadanDayRow: Identifiable {
  var day: Int
  var date: Date
  var imsak: String
  var iftar: String
  var id: Int { day }
}

struct RamadanState {
  var day: Int
  var total: Int
  var fastedDays: Set<Int>
  var fastedToday: Bool
  var countdownIsSahur: Bool
  var target: Date?
  var imsak: String
  var iftar: String
  var rows: [RamadanDayRow]

  var count: Int { fastedDays.count }

  /// Widget galerisi için örnek gün.
  static func gallerySample(at now: Date) -> RamadanState {
    let today = Calendar.current.startOfDay(for: now)
    let rows = (5...11).map { d in
      RamadanDayRow(
        day: d, date: Calendar.current.date(byAdding: .day, value: d - 5, to: today) ?? today,
        imsak: String(format: "05:%02d", 50 - d), iftar: String(format: "18:%02d", 20 + d))
    }
    return RamadanState(
      day: 5, total: 29, fastedDays: [1, 2, 3, 4], fastedToday: false, countdownIsSahur: false, target: now.addingTimeInterval(6 * 3600),
      imsak: "05:45", iftar: "18:25", rows: rows)
  }

  static func make(at now: Date) -> RamadanState? {
    guard let data = RamadanData.load(), data.on,
      let start = dayDate(data.start), let last = dayDate(data.last) else { return nil }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    guard today >= start, today <= last else { return nil }
    let stored = (UserDefaults(suiteName: appGroupID)?.data(forKey: "salah_widget_data")).flatMap { try? JSONDecoder().decode(WidgetData.self, from: $0) }
    let days = stored?.days ?? []
    let number = { (date: Date) in (calendar.dateComponents([.day], from: start, to: date).day ?? 0) + 1 }
    let fastedDays = Set(data.fasted.compactMap { dayDate($0).map(number) })
    let current = stored?.resolved(for: now)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
    let tomorrowImsak = days.first { $0.date == dayKey(tomorrow) }?.imsak
    var target: Date?
    var isSahur = false
    if let imsak = current.flatMap({ clock($0.imsak, on: today) }), let aksam = current.flatMap({ clock($0.aksam, on: today) }) {
      if now < imsak {
        target = imsak; isSahur = true
      } else if now < aksam {
        target = aksam
      } else if today < last {
        target = tomorrowImsak.flatMap { clock($0, on: tomorrow) }; isSahur = true
      }
    }
    let rows: [RamadanDayRow] = days.compactMap { d in
      guard let date = dayDate(d.date), date >= today, date <= last else { return nil }
      return RamadanDayRow(day: number(date), date: date, imsak: d.imsak, iftar: d.aksam)
    }
    let day = number(today)
    return RamadanState(
      day: day, total: data.total, fastedDays: fastedDays, fastedToday: fastedDays.contains(day), countdownIsSahur: isSahur, target: target,
      imsak: isSahur && target != nil && now >= (current.flatMap { clock($0.aksam, on: today) } ?? .distantFuture) ? (tomorrowImsak ?? "--:--") : (current?.imsak ?? "--:--"),
      iftar: current?.aksam ?? "--:--", rows: rows)
  }

  private static func dayDate(_ key: String) -> Date? {
    let p = key.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return nil }
    return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
  }

  private static func clock(_ raw: String, on day: Date) -> Date? {
    let p = raw.split(separator: ":").compactMap { Int($0) }
    guard p.count >= 2 else { return nil }
    return Calendar.current.date(bySettingHour: p[0], minute: p[1], second: 0, of: day)
  }
}

struct RamadanEntry: TimelineEntry {
  let date: Date
  let state: RamadanState?
}

struct RamadanProvider: TimelineProvider {
  func placeholder(in _: Context) -> RamadanEntry { RamadanEntry(date: Date(), state: .gallerySample(at: Date())) }
  func getSnapshot(in context: Context, completion: @escaping (RamadanEntry) -> Void) {
    // Galeride Ramazan dışında da tasarım görünsün.
    let now = Date()
    completion(RamadanEntry(date: now, state: context.isPreview ? .gallerySample(at: now) : RamadanState.make(at: now)))
  }
  func getTimeline(in _: Context, completion: @escaping (Timeline<RamadanEntry>) -> Void) {
    let now = Date()
    let calendar = Calendar.current
    // Sayaç bitince hedef değişir; gece yarısı gün değişir.
    var dates = [now]
    var cursor = now
    for _ in 0..<4 {
      guard let target = RamadanState.make(at: cursor)?.target else { break }
      let next = target.addingTimeInterval(1)
      dates.append(next)
      cursor = next
    }
    if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) { dates.append(midnight.addingTimeInterval(1)) }
    let entries = dates.sorted().map { RamadanEntry(date: $0, state: RamadanState.make(at: $0)) }
    completion(Timeline(entries: entries, policy: .after(calendar.date(byAdding: .hour, value: 6, to: now) ?? now)))
  }
}

// MARK: - Ay

private struct MoonLit: Shape {
  let day: Int

  func path(in rect: CGRect) -> Path {
    let cycle = 29.53
    let side = Double(day) / cycle < 0.5 ? 1.0 : -1.0
    let f = max(0.05, (1 - cos(2 * .pi * Double(day) / cycle)) / 2)
    let r = min(rect.width, rect.height) / 2
    let steps = 28
    var path = Path()
    for i in 0...steps {
      let a = -Double.pi / 2 + .pi * Double(i) / Double(steps)
      let point = CGPoint(x: rect.midX + side * cos(a) * r, y: rect.midY + sin(a) * r)
      if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    for i in (0...steps).reversed() {
      let a = -Double.pi / 2 + .pi * Double(i) / Double(steps)
      path.addLine(to: CGPoint(x: rect.midX + side * cos(a) * (1 - 2 * f) * r, y: rect.midY + sin(a) * r))
    }
    path.closeSubpath()
    return path
  }
}

struct RamadanMoon: View {
  let day: Int
  let size: CGFloat
  let disc: Color
  let lit: Color

  var body: some View {
    ZStack {
      Circle().fill(disc)
      MoonLit(day: day).fill(lit)
    }
    .frame(width: size, height: size)
    .environment(\.layoutDirection, .leftToRight)
    .accessibilityHidden(true)
  }
}

private struct RamadanEmptyView: View {
  let theme: SalahTheme

  var body: some View {
    VStack(spacing: 10) {
      RamadanMoon(day: 3, size: 44, disc: theme.fill, lit: Color.gold(theme))
      Text(WL.t("ramadanW.empty")).font(.system(size: 12)).foregroundColor(theme.textSecondary).multilineTextAlignment(.center)
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private func onGold(_ theme: SalahTheme) -> Color {
  theme.isDark ? WidgetAppColor.palette.accent(9) : .white
}

private func untilLabel(_ state: RamadanState) -> String {
  WL.t(state.countdownIsSahur ? "ramadanW.untilSahur" : "ramadanW.untilIftar")
}

private struct RamadanClock: View {
  let state: RamadanState
  let date: Date
  let size: CGFloat
  let color: Color

  var body: some View {
    Group {
      if let target = state.target, target > date {
        Text(timerInterval: date...target, countsDown: true)
      } else {
        Text(verbatim: "--:--")
      }
    }
    .font(.system(size: size, weight: .light))
    .monospacedDigit()
    .foregroundColor(color)
    .lineLimit(1)
    .minimumScaleFactor(0.7)
    .environment(\.layoutDirection, .leftToRight)
  }
}

// MARK: - Oruç

struct RamadanFastSmallView: View {
  let entry: RamadanEntry
  let theme: SalahTheme

  var body: some View {
    if let state = entry.state {
      VStack(alignment: .leading, spacing: 0) {
        Text(WL.t("ramadanW.day", "\(state.day)")).font(.system(size: 12, weight: .semibold)).foregroundColor(Color.gold(theme))
        Spacer(minLength: 0)
        Text(untilLabel(state)).font(.system(size: 12)).foregroundColor(theme.textSecondary).lineLimit(1)
        RamadanClock(state: state, date: entry.date, size: 30, color: theme.textPrimary)
        Text(WL.t("ramadanW.count", "\(state.count)", "\(state.total)")).font(.system(size: 12)).foregroundColor(theme.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
      }
      .padding(15)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .background(alignment: .topTrailing) {
        RamadanMoon(day: state.day, size: 76, disc: theme.fill, lit: Color.gold(theme)).offset(x: 14, y: -14)
      }
      .clipped()
    } else {
      RamadanEmptyView(theme: theme)
    }
  }
}

struct RamadanFastMediumView: View {
  let entry: RamadanEntry
  let theme: SalahTheme

  var body: some View {
    if let state = entry.state {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 1) {
            Text(untilLabel(state)).font(.system(size: 12)).foregroundColor(theme.textSecondary).lineLimit(1)
            RamadanClock(state: state, date: entry.date, size: 36, color: theme.textPrimary)
          }
          Spacer(minLength: 8)
          Button(intent: FastTodayIntent()) {
            ZStack {
              if state.fastedToday {
                Circle().fill(Color.gold(theme))
              } else {
                Circle().stroke(Color.gold(theme), lineWidth: 1.5)
              }
              Image(systemName: state.fastedToday ? "checkmark" : "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(state.fastedToday ? onGold(theme) : Color.gold(theme))
            }
            .frame(width: 46, height: 46)
          }
          .buttonStyle(.plain)
        }
        Spacer(minLength: 0)
        HStack(spacing: 3) {
          ForEach(1...max(1, state.total), id: \.self) { i in
            Capsule()
              .fill(state.fastedDays.contains(i) ? Color.gold(theme) : i == state.day ? theme.textPrimary : theme.fill)
              .frame(height: 8)
          }
        }
        HStack {
          Text(WL.t("ramadanW.day", "\(state.day)"))
          Spacer(minLength: 6)
          Text(WL.t("ramadanW.count", "\(state.count)", "\(state.total)"))
        }
        .font(.system(size: 12)).foregroundColor(theme.textSecondary).lineLimit(1).padding(.top, 7)
      }
      .padding(15)
    } else {
      RamadanEmptyView(theme: theme)
    }
  }
}

/// Orta widget düğmesi: işareti App Group'a yazar, uygulama açılınca deftere ve sunucuya geçer.
struct FastTodayIntent: AppIntent {
  static var title: LocalizedStringResource = "Mark Fast"

  func perform() async throws -> some IntentResult {
    guard let ud = UserDefaults(suiteName: appGroupID), var data = RamadanData.load() else { return .result() }
    let key = dayKey(Date())
    let fasted = !data.fasted.contains(key)
    if fasted { data.fasted.append(key) } else { data.fasted.removeAll { $0 == key } }
    if let encoded = try? JSONEncoder().encode(data) { ud.set(encoded, forKey: "salah_ramadan_data") }
    var marks = ud.dictionary(forKey: "salah_ramadan_widget_marks") as? [String: Bool] ?? [:]
    marks[key] = fasted
    ud.set(marks, forKey: "salah_ramadan_widget_marks")
    WidgetCenter.shared.reloadTimelines(ofKind: "SalahRamadanFastWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "SalahRamadanLockWidget")
    return .result()
  }
}

// MARK: - İmsakiye

struct RamadanTableSmallView: View {
  let entry: RamadanEntry
  let theme: SalahTheme

  var body: some View {
    if let state = entry.state {
      VStack(alignment: .leading, spacing: 0) {
        Text(entry.date.formatted(Date.FormatStyle.dateTime.day().month(.wide).locale(Locale(identifier: WL.lang))))
          .font(.system(size: 12, weight: .semibold)).foregroundColor(Color.gold(theme)).lineLimit(1)
        Spacer(minLength: 0)
        Text(WL.t("ramadanW.imsak")).font(.system(size: 12)).foregroundColor(theme.textSecondary)
        Text(state.rows.first?.imsak ?? state.imsak).font(.system(size: 26, weight: .light)).monospacedDigit().foregroundColor(theme.textPrimary)
        Text(WL.t("ramadanW.iftar")).font(.system(size: 12)).foregroundColor(Color.gold(theme)).padding(.top, 5)
        Text(state.iftar).font(.system(size: 26, weight: .medium)).monospacedDigit().foregroundColor(Color.gold(theme))
      }
      .padding(15)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    } else {
      RamadanEmptyView(theme: theme)
    }
  }
}

struct RamadanTableListView: View {
  let entry: RamadanEntry
  let theme: SalahTheme
  let count: Int

  var body: some View {
    if let state = entry.state {
      VStack(spacing: 0) {
        HStack(alignment: .firstTextBaseline) {
          Text(WL.t("ramadanW.table.name")).font(.system(size: 15, weight: .semibold)).foregroundColor(theme.textPrimary).lineLimit(1)
          Spacer(minLength: 8)
          Text(WL.t("ramadanW.imsak")).frame(width: 48, alignment: .trailing)
          Text(WL.t("ramadanW.iftar")).frame(width: 48, alignment: .trailing)
        }
        .font(.system(size: 11))
        .foregroundColor(theme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        VStack(spacing: 0) {
          ForEach(state.rows.prefix(count)) { row in
            let on = row.day == state.day
            HStack(spacing: 0) {
              Text("\(row.day)").frame(width: 26, alignment: .leading)
              Text(row.date.formatted(Date.FormatStyle.dateTime.day().month(.abbreviated).weekday(.abbreviated).locale(Locale(identifier: WL.lang))))
                .lineLimit(1).minimumScaleFactor(0.8)
              Spacer(minLength: 6)
              Text(row.imsak).frame(width: 48, alignment: .trailing)
              Text(row.iftar).frame(width: 48, alignment: .trailing)
            }
            .font(.system(size: 13.5, weight: on ? .semibold : .regular))
            .monospacedDigit()
            .foregroundColor(on ? onGold(theme) : theme.textPrimary)
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
            .background(on ? Color.gold(theme) : .clear, in: RoundedRectangle(cornerRadius: 12))
          }
        }
      }
      .padding(15)
    } else {
      RamadanEmptyView(theme: theme)
    }
  }
}

// MARK: - Kilit ekranı

struct RamadanLockView: View {
  @Environment(\.widgetFamily) private var family
  let entry: RamadanEntry

  var body: some View {
    if let state = entry.state {
      switch family {
      case .accessoryCircular:
        VStack(spacing: 2) {
          RamadanMoon(day: state.day, size: 24, disc: Color.primary.opacity(0.2), lit: .primary).widgetAccentable()
          Text(verbatim: "\(state.count)/\(state.total)").font(.system(size: 12, weight: .semibold)).monospacedDigit()
        }
      default:
        // Geri sayımın yanında yalnız saat.
        VStack(alignment: .leading, spacing: 0) {
          Text(WL.t(state.countdownIsSahur ? "ramadanW.sahur" : "ramadanW.iftar")).font(.system(size: 13, weight: .semibold)).widgetAccentable()
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let target = state.target, target > entry.date {
              Text(timerInterval: entry.date...target, countsDown: true).font(.system(size: 22, weight: .medium)).monospacedDigit().lineLimit(1)
              Text(formatClock(target)).font(.system(size: 13)).foregroundStyle(.secondary).monospacedDigit()
            } else {
              Text(state.iftar).font(.system(size: 22, weight: .medium)).monospacedDigit()
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    } else {
      Image(systemName: "moon.stars").font(.system(size: 18, weight: .medium))
    }
  }

  private func formatClock(_ date: Date) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
  }
}

// MARK: - Tanımlar

struct RamadanFastWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "SalahRamadanFastWidget", provider: RamadanProvider()) { entry in
      SystemThemed { theme in RamadanFastEntryView(entry: entry, theme: theme).galleryPlaceholderReadable() }
        .widgetURL(URL(string: "salah://oruc"))
    }
    .contentMarginsDisabled()
    .configurationDisplayName(WL.t("ramadanW.fast.name"))
    .description(WL.t("ramadanW.fast.desc"))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

private struct RamadanFastEntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: RamadanEntry
  let theme: SalahTheme

  var body: some View {
    if family == .systemSmall { RamadanFastSmallView(entry: entry, theme: theme) } else { RamadanFastMediumView(entry: entry, theme: theme) }
  }
}

struct RamadanTimetableWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "SalahRamadanTimetableWidget", provider: RamadanProvider()) { entry in
      SystemThemed { theme in RamadanTableEntryView(entry: entry, theme: theme).galleryPlaceholderReadable() }
        .widgetURL(URL(string: "salah://imsakiye"))
    }
    .contentMarginsDisabled()
    .configurationDisplayName(WL.t("ramadanW.table.name"))
    .description(WL.t("ramadanW.table.desc"))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

private struct RamadanTableEntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: RamadanEntry
  let theme: SalahTheme

  var body: some View {
    switch family {
    case .systemSmall: RamadanTableSmallView(entry: entry, theme: theme)
    case .systemMedium: RamadanTableListView(entry: entry, theme: theme, count: 3)
    default: RamadanTableListView(entry: entry, theme: theme, count: 7)
    }
  }
}

struct RamadanLockWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "SalahRamadanLockWidget", provider: RamadanProvider()) { entry in
      RamadanLockView(entry: entry)
        .lockWidgetBackground()
        .widgetURL(URL(string: "salah://oruc"))
    }
    .configurationDisplayName(WL.t("ramadanW.lock.name"))
    .description(WL.t("ramadanW.lock.desc"))
    .supportedFamilies([.accessoryCircular, .accessoryRectangular])
  }
}

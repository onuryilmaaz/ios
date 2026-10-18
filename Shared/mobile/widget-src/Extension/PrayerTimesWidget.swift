import SwiftUI
import WidgetKit

struct PrayerTimesEntry: TimelineEntry {
  let date: Date
  let data: WidgetData?
  let tracker: TrackerData?
  let theme: SalahTheme

  /// O anki / sıradaki vakit — kılınan namazlar hesaba katılır.
  var window: PrayerWindowState? {
    computePrayerWindow(data: data, completed: tracker?.completedPrayers ?? [], at: date)
  }
}

struct PrayerTimesProvider: TimelineProvider {
  let theme: SalahTheme

  func placeholder(in _: Context) -> PrayerTimesEntry {
    PrayerTimesEntry(date: Date(), data: nil, tracker: nil, theme: theme)
  }
  func getSnapshot(in _: Context, completion: @escaping (PrayerTimesEntry) -> Void) {
    completion(PrayerTimesEntry(date: Date(), data: WidgetData.load(), tracker: TrackerData.load(), theme: theme))
  }
  func getTimeline(in _: Context, completion: @escaping (Timeline<PrayerTimesEntry>) -> Void) {
    let data = WidgetData.load()
    let tracker = TrackerData.load()
    let cal = Calendar.current
    let now = Date()
    var entries: [PrayerTimesEntry] = [PrayerTimesEntry(date: now, data: data, tracker: tracker, theme: theme)]

    for timeStr in [data?.imsak, data?.gunes, data?.ogle, data?.ikindi, data?.aksam, data?.yatsi].compactMap({ $0 }) {
      let parts = timeStr.split(separator: ":").compactMap { Int($0) }
      guard parts.count >= 2 else { continue }
      var c = cal.dateComponents([.year, .month, .day], from: now)
      c.hour = parts[0]; c.minute = parts[1]; c.second = 1
      if let d = cal.date(from: c), d > now {
        entries.append(PrayerTimesEntry(date: d, data: data, tracker: tracker, theme: theme))
      }
    }

    // Alarm çaldıktan sonra "sıradaki alarm" güncellensin.
    for alarm in alarmDates(within: 24 * 3600, from: now) {
      entries.append(PrayerTimesEntry(date: alarm.addingTimeInterval(1), data: data, tracker: tracker, theme: theme))
    }
    entries.sort { $0.date < $1.date }

    let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
    completion(Timeline(entries: entries, policy: .after(midnight)))
  }
}

// MARK: - Day Schedule

private struct PrayerSlot {
  let id: String         // "sabah", "gunes", "ogle"...
  let label: String      // "Sabah", "Güneş"...
  let time: String       // "06:15"
  let isActive: Bool     // şu an bu vaktin içindeyiz
  let isPast: Bool       // vakti geçti
  let isPrayed: Bool     // namaz takibinde kılındı işaretli
  let isMarker: Bool     // namaz değil, sınır anı (Güneş)
}

private func timeToMinutes(_ s: String) -> Int {
  let parts = s.split(separator: ":").compactMap { Int($0) }
  guard parts.count >= 2 else { return -1 }
  return parts[0] * 60 + parts[1]
}

private func buildDaySlots(entry: PrayerTimesEntry) -> [PrayerSlot] {
  guard let w = entry.data else { return [] }
  let entries: [(String, String, String)] = [
    ("sabah", WL.prayer("sabah"), w.imsak), ("gunes", WL.prayer("gunes"), w.gunes),
    ("ogle", WL.prayer("ogle"), w.ogle), ("ikindi", WL.prayer("ikindi"), w.ikindi),
    ("aksam", WL.prayer("aksam"), w.aksam), ("yatsi", WL.prayer("yatsi"), w.yatsi),
  ]
  let c = Calendar.current.dateComponents([.hour, .minute], from: entry.date)
  let nowMin = (c.hour ?? 0) * 60 + (c.minute ?? 0)
  let completed = entry.tracker?.completedPrayers ?? []

  // İçinde bulunulan vakit = başlangıcı geçmiş en son vakit. Güneş'ten sonra
  // (öğle girene dek) aktif namaz vakti yoktur; gece yarısından sonra Yatsı sürer.
  var active: String? = nowMin < timeToMinutes(w.imsak) ? "yatsi" : nil
  for (id, _, time) in entries where timeToMinutes(time) >= 0 && nowMin >= timeToMinutes(time) {
    active = id
  }
  if active == "gunes" { active = nil }

  return entries.map { id, label, time in
    let start = timeToMinutes(time)
    let isActive = id == active
    return PrayerSlot(
      id: id, label: label, time: time, isActive: isActive,
      isPast: start >= 0 && nowMin >= start && !isActive,
      isPrayed: id != "gunes" && isPrayerCompleted(id, in: completed),
      isMarker: id == "gunes")
  }
}

// MARK: - Shared pieces

/// "Öğle Vakti" / "Öğle Vaktine" başlığı.
/// Tek cümlelik başlık ("İkindi vaktinin çıkmasına") ve hemen altında sayaç.
private struct CountdownBlock: View {
  let window: PrayerWindowState
  let theme: SalahTheme
  let size: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(window.headline)
        .font(.caption.weight(.medium))
        .foregroundColor(theme.textSecondary)
        .lineLimit(2)
        .minimumScaleFactor(0.85)
        .fixedSize(horizontal: false, vertical: true)
      Text(timerInterval: Date.now...max(Date.now, window.endDate), pauseTime: nil, countsDown: true)
        .font(.widgetHero(size))
        .foregroundColor(theme.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .widgetAccentable()
    }
  }
}

/// Vaktin ilerleme çubuğu (o anki vakitte) ve çıkış/giriş saati.
private struct WindowFooter: View {
  let window: PrayerWindowState
  let now: Date
  let theme: SalahTheme

  var body: some View {
    let tint = prayerAccent(window.key, theme)
    VStack(alignment: .leading, spacing: 6) {
      if let p = window.progress(at: now) {
        ProgressCapsule(progress: p, tint: tint, track: theme.fill)
      }
      Text(window.footnote)
        .font(.caption2.weight(.semibold))
        .foregroundColor(theme.textSecondary)
        .monospacedDigit()
        .lineLimit(1)
    }
  }
}

private struct EmptyPrayerState: View {
  let theme: SalahTheme
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "clock")
        .font(.system(size: 20, weight: .medium))
      Text(WL.t("window.openApp"))
        .font(.caption.weight(.medium))
        .multilineTextAlignment(.center)
    }
    .foregroundColor(theme.textSecondary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Alarm Button

/// Orta/büyük widget'ın köşesi: iOS 26+ (AlarmKit) varsa alarm düğmesi
/// (Alarmlar ekranını açar, sıradaki alarmı gösterir), yoksa vakit ikonu.
private struct HeaderBadge: View {
  let key: String
  let now: Date
  let theme: SalahTheme
  let size: CGFloat

  var body: some View {
    if #available(iOS 26.0, *) {
      AlarmButton(next: nextAlarmDate(after: now), theme: theme, size: size)
    } else {
      PrayerBadge(key: key, theme: theme, size: size)
        .accessibilityHidden(true)
    }
  }
}

private struct AlarmButton: View {
  let next: Date?
  let theme: SalahTheme
  let size: CGFloat

  var body: some View {
    let tint = Color.gold(theme)
    Link(destination: URL(string: "salah://alarms")!) {
      HStack(spacing: 6) {
        ZStack {
          Circle().fill(tint.opacity(theme.isDark ? 0.18 : 0.13))
          Image(systemName: next == nil ? "alarm" : "alarm.fill")
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundColor(tint)
            .widgetAccentable()
        }
        .frame(width: size, height: size)
        if let next {
          Text(next, format: .dateTime.hour().minute())
            .font(.system(size: size * 0.42, weight: .semibold))
            .monospacedDigit()
            .foregroundColor(tint)
        }
      }
    }
    .accessibilityLabel(
      next.map { WL.t("alarmW.next", $0.formatted(date: .omitted, time: .shortened)) } ?? WL.t("alarmW.open"))
  }
}

// MARK: - Small

struct PrayerTimesSmallView: View {
  let entry: PrayerTimesEntry
  private var t: SalahTheme { entry.theme }

  var body: some View {
    if let w = entry.window {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 7) {
          PrayerBadge(key: w.key, theme: t, size: 28)
          Spacer(minLength: 0)
        }
        Spacer(minLength: 6)
        CountdownBlock(window: w, theme: t, size: 30)
        Spacer(minLength: 10)
        WindowFooter(window: w, now: entry.date, theme: t)
      }
      .accessibilityElement(children: .combine)
      .padding(15)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    } else {
      EmptyPrayerState(theme: t)
    }
  }
}

// MARK: - Medium — sol: o anki vakit, sağ: günün vakitleri

struct PrayerTimesMediumView: View {
  let entry: PrayerTimesEntry
  private var t: SalahTheme { entry.theme }

  var body: some View {
    if let w = entry.window {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 7) {
            HeaderBadge(key: w.key, now: entry.date, theme: t, size: 28)
            Spacer(minLength: 0)
          }
          Spacer(minLength: 6)
          CountdownBlock(window: w, theme: t, size: 30)
          Spacer(minLength: 8)
          WindowFooter(window: w, now: entry.date, theme: t)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, alignment: .leading)

        Rectangle().fill(t.hairline).frame(width: 1)

        VStack(spacing: 0) {
          ForEach(buildDaySlots(entry: entry), id: \.id) { slot in
            CompactSlotRow(slot: slot, theme: t)
            if slot.id != "yatsi" { Spacer(minLength: 0) }
          }
        }
        // Sıkışık liste: büyük yazı boyutunda taşmasın diye varsayılanda sabit.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .frame(width: 118)
      }
      .padding(15)
    } else {
      EmptyPrayerState(theme: t)
    }
  }
}

private func slotAccessibilityLabel(_ slot: PrayerSlot) -> String {
  var parts = ["\(slot.label) \(slot.time)"]
  if slot.isActive { parts.append(WL.t("window.nowLower")) }
  if slot.isPrayed { parts.append(WL.t("window.prayed")) }
  return parts.joined(separator: ", ")
}

private struct CompactSlotRow: View {
  let slot: PrayerSlot
  let theme: SalahTheme

  var body: some View {
    let tint = prayerAccent(slot.id, theme)
    HStack(spacing: 6) {
      Circle()
        .fill(slot.isActive ? tint : Color.clear)
        .frame(width: 5, height: 5)
      Text(slot.label)
        .font(.system(.footnote, design: .default, weight: slot.isActive ? .semibold : .regular))
        .foregroundColor(
          slot.isActive ? theme.textPrimary : slot.isPast || slot.isMarker ? theme.textTertiary : theme.textSecondary)
      Spacer(minLength: 4)
      if slot.isPrayed {
        Image(systemName: "checkmark")
          .font(.system(size: 9, weight: .bold))
          .foregroundColor(Color.brand(theme))
      }
      Text(slot.time)
        .font(.system(.footnote, design: .default, weight: slot.isActive ? .semibold : .regular))
        .monospacedDigit()
        .foregroundColor(slot.isActive ? tint : slot.isPast ? theme.textTertiary : theme.textSecondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(slotAccessibilityLabel(slot))
  }
}

// MARK: - Large — başlık, gün şeridi, tüm vakitler

struct PrayerTimesLargeView: View {
  let entry: PrayerTimesEntry
  private var t: SalahTheme { entry.theme }

  var body: some View {
    if let w = entry.window {
      let tint = prayerAccent(w.key, t)
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top) {
          CountdownBlock(window: w, theme: t, size: 38)
          Spacer()
          HeaderBadge(key: w.key, now: entry.date, theme: t, size: 40)
        }
        .accessibilityElement(children: .combine)

        DayRail(data: entry.data, now: entry.date, tint: tint, theme: t)
          .padding(.top, 16)
          .padding(.bottom, 14)

        VStack(spacing: 2) {
          ForEach(buildDaySlots(entry: entry), id: \.id) { slot in
            LargeSlotRow(slot: slot, theme: t)
          }
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        Spacer(minLength: 0)
      }
      .padding(16)
    } else {
      EmptyPrayerState(theme: t)
    }
  }
}

private struct LargeSlotRow: View {
  let slot: PrayerSlot
  let theme: SalahTheme

  var body: some View {
    let tint = prayerAccent(slot.id, theme)
    let dim = (slot.isPast || slot.isMarker) && !slot.isActive
    HStack(spacing: 12) {
      Image(systemName: prayerIcon(slot.id))
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(slot.isActive ? tint : dim ? theme.textTertiary : theme.textSecondary)
        .frame(width: 22)
      Text(slot.label)
        .font(.system(.subheadline, design: .default, weight: slot.isActive ? .semibold : .regular))
        .foregroundColor(slot.isActive ? theme.textPrimary : dim ? theme.textTertiary : theme.textPrimary)
      Spacer()
      if slot.isPrayed {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 13))
          .foregroundColor(Color.brand(theme))
      }
      if slot.isActive {
        Text(WL.t("window.now"))
          .font(.caption2.weight(.semibold))
          .foregroundColor(tint)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Capsule().fill(tint.opacity(theme.isDark ? 0.18 : 0.12)))
      }
      Text(slot.time)
        .font(.system(.subheadline, design: .default, weight: slot.isActive ? .semibold : .regular))
        .monospacedDigit()
        .foregroundColor(slot.isActive ? theme.textPrimary : dim ? theme.textTertiary : theme.textSecondary)
        .frame(width: 46, alignment: .trailing)
    }
    .padding(.horizontal, 10)
    .frame(height: 36)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(slotAccessibilityLabel(slot))
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(slot.isActive ? tint.opacity(theme.isDark ? 0.12 : 0.08) : Color.clear))
  }
}

// MARK: - Entry View

struct PrayerTimesWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: PrayerTimesEntry

  var body: some View {
    switch family {
    case .systemSmall:
      PrayerTimesSmallView(entry: entry)
    case .systemLarge:
      PrayerTimesLargeView(entry: entry)
    default:
      PrayerTimesMediumView(entry: entry)
    }
  }
}

// MARK: - Lock Screen

struct NextPrayerLockView: View {
  let entry: PrayerTimesEntry
  @Environment(\.widgetFamily) var family

  var body: some View {
    if let w = entry.window {
      // Saati gösterilen vakit: vaktin içindeyken sıradaki vaktin girişi
      // (Öğle'deyken "İkindi 16:09"), vakit girmediyse o vaktin kendisi.
      let nextName = WL.prayer(w.mode == .current ? w.nextPrayer : w.prayerName)
      switch family {
      case .accessoryCircular:
        Gauge(value: w.progress(at: entry.date) ?? 0) {
          Image(systemName: prayerIcon(w.key))
        } currentValueLabel: {
          Image(systemName: prayerIcon(w.key))
            .font(.system(size: 16, weight: .semibold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()

      case .accessoryRectangular:
        NextPrayerRectContent(window: w)

      default:
        Label {
          Text("\(nextName) \(w.endTime)")
        } icon: {
          Image(systemName: prayerIcon(w.key))
        }
      }
    } else {
      Image(systemName: "clock")
    }
  }
}

/// Dikdörtgen kilit ekranı widget'ı: başlık, geri sayım ve sıradaki vaktin saati.
///
/// Geri sayımın yanına vakit adı eklemeyin: `Text(timerInterval:)` küçülmez ve
/// cihazda yer kalmayınca "8:56…" diye kesiliyor (1.0.6'da yaşandı).
struct NextPrayerRectContent: View {
  let window: PrayerWindowState

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      HStack(spacing: 4) {
        Image(systemName: prayerIcon(window.key))
          .font(.system(size: 11, weight: .semibold))
        Text(window.headline)
          .font(.footnote.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .widgetAccentable()
      // Kalan süre ve ezanın okunacağı saat (o anki vakitte: sıradaki vaktin girişi).
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(timerInterval: Date.now...max(Date.now, window.endDate), pauseTime: nil, countsDown: true)
          .font(.system(size: 26, weight: .medium).monospacedDigit())
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Spacer(minLength: 0)
        Text(window.endTime)
          .font(.system(size: 15, weight: .semibold).monospacedDigit())
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .fixedSize()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SalahNextPrayerLockWidget: Widget {
  let kind = "SalahNextPrayerLockWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PrayerTimesProvider(theme: .dark)) { entry in
      NextPrayerLockView(entry: entry)
        .lockWidgetBackground()
        .widgetURL(URL(string: "salah://home"))
    }
    .configurationDisplayName(WL.t("times.current.name"))
    .description(WL.t("times.current.desc"))
    .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}

// MARK: - Widget Definitions

struct PrayerTimesWidget: Widget {
  let kind = "SalahPrayerTimesWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PrayerTimesProvider(theme: .dark)) { entry in
      HeroThemed { theme in
        PrayerTimesWidgetEntryView(entry: PrayerTimesEntry(date: entry.date, data: entry.data, tracker: entry.tracker, theme: theme))
      }
      .widgetURL(URL(string: "salah://home"))
    }
    .configurationDisplayName(WL.t("times.list.name"))
    .description(WL.t("times.list.desc"))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

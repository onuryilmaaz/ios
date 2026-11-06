import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Entry & Provider

struct PrayerTrackerEntry: TimelineEntry {
  let date: Date
  let tracker: TrackerData?
  let widget: WidgetData?
  let theme: SalahTheme
}

// MARK: - Provider

struct PrayerTrackerProvider: TimelineProvider {
  let theme: SalahTheme

  func placeholder(in _: Context) -> PrayerTrackerEntry {
    PrayerTrackerEntry(date: Date(), tracker: nil, widget: nil, theme: theme)
  }
  func getSnapshot(in _: Context, completion: @escaping (PrayerTrackerEntry) -> Void) {
    completion(PrayerTrackerEntry(date: Date(), tracker: TrackerData.load(), widget: WidgetData.load(), theme: theme))
  }
  func getTimeline(in _: Context, completion: @escaping (Timeline<PrayerTrackerEntry>) -> Void) {
    completion(buildTrackerTimeline(theme: theme))
  }
}

// MARK: - Shared timeline builder

private func buildTrackerTimeline(theme: SalahTheme) -> Timeline<PrayerTrackerEntry> {
  let widget = WidgetData.load()
  let tracker = TrackerData.load()
  let cal = Calendar.current
  let now = Date()
  var entries: [PrayerTrackerEntry] = [PrayerTrackerEntry(date: now, tracker: tracker, widget: widget, theme: theme)]

  for timeStr in [widget?.imsak, widget?.gunes, widget?.ogle, widget?.ikindi, widget?.aksam, widget?.yatsi].compactMap({ $0 }) {
    let parts = timeStr.split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2 else { continue }
    var c = cal.dateComponents([.year, .month, .day], from: now)
    c.hour = parts[0]; c.minute = parts[1]; c.second = 1
    if let d = cal.date(from: c), d > now {
      entries.append(PrayerTrackerEntry(date: d, tracker: tracker, widget: widget, theme: theme))
    }
  }

  // 04:00: sunucu yeni güne geçer, imsaka kadar işaretleme kapanır.
  if let rollover = cal.date(bySettingHour: 4, minute: 0, second: 1, of: now), rollover > now {
    entries.append(PrayerTrackerEntry(date: rollover, tracker: tracker, widget: widget, theme: theme))
  }
  entries.sort { $0.date < $1.date }

  let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
  return Timeline(entries: entries, policy: .after(midnight))
}

// MARK: - Prayer Definitions

struct PrayerInfo {
  let id: String
  let label: String
  let timeKey: String
}

let allPrayers: [PrayerInfo] = [
  PrayerInfo(id: "sabah",  label: WL.prayer("sabah"),  timeKey: "imsak"),
  PrayerInfo(id: "ogle",   label: WL.prayer("ogle"),   timeKey: "ogle"),
  PrayerInfo(id: "ikindi", label: WL.prayer("ikindi"), timeKey: "ikindi"),
  PrayerInfo(id: "aksam",  label: WL.prayer("aksam"),  timeKey: "aksam"),
  PrayerInfo(id: "yatsi",  label: WL.prayer("yatsi"),  timeKey: "yatsi"),
]

/// Sunucunun namaz günü 04:00'te değişir (backend islamicDateStr). 04:00 ile imsak arasında yapılan işaret
/// bugünün henüz girmemiş vaktine yazılırdı; bu arada hiçbir vakit işaretlenemez (uygulamadaki kural).
let trackerDayRolloverMinutes = 4 * 60

private func hhmmMinutes(_ s: String) -> Int? {
  let parts = s.split(separator: ":").compactMap { Int($0) }
  guard parts.count >= 2 else { return nil }
  return parts[0] * 60 + parts[1]
}

/// Vakit girdi mi (işaretlenebilir mi)? Uygulamadaki PrayerTrackerCard.slotState ile aynı kural:
/// gece yarısı–imsak arası önceki namaz günü (Sabah…Akşam kaza, Yatsı o anki vakit), yalnız 04:00'ten önce.
func isPrayerAvailable(_ p: PrayerInfo, widget: WidgetData?, at date: Date = Date()) -> Bool {
  guard let w = widget else { return false }
  let timeStr: String
  switch p.timeKey {
  case "imsak":  timeStr = w.imsak
  case "ogle":   timeStr = w.ogle
  case "ikindi": timeStr = w.ikindi
  case "aksam":  timeStr = w.aksam
  case "yatsi":  timeStr = w.yatsi
  default: return false
  }
  guard let pMin = hhmmMinutes(timeStr) else { return false }
  let now = Calendar.current.dateComponents([.hour, .minute], from: date)
  let nowMin = (now.hour ?? 0) * 60 + (now.minute ?? 0)
  if let imsakMin = hhmmMinutes(w.imsak), nowMin < imsakMin {
    return nowMin < trackerDayRolloverMinutes
  }
  return nowMin >= pMin
}

// MARK: - Shared

private struct TrackerState {
  let completed: [String]
  let kaza: [String]

  init(_ entry: PrayerTrackerEntry) {
    completed = entry.tracker?.completedPrayers ?? []
    kaza = entry.tracker?.kazaPrayers ?? []
  }

  func isDone(_ id: String) -> Bool { isPrayerCompleted(id, in: completed) }
  func isKaza(_ id: String) -> Bool { isDone(id) && isPrayerKaza(id, in: kaza) }
  var count: Int { allPrayers.filter { isDone($0.id) }.count }

  var subtitle: String {
    switch count {
    case 5: return WL.t("tracker.allDone")
    case 0: return WL.t("tracker.allPending")
    default: return WL.t("tracker.left", String(5 - count))
    }
  }
}

private struct CountLabel: View {
  let count: Int
  let theme: SalahTheme
  let size: CGFloat

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 2) {
      Text("\(count)")
        .font(.widgetHero(size))
        .foregroundColor(theme.textPrimary)
        .widgetAccentable()
      Text("/5")
        .font(.system(size: size * 0.42, weight: .semibold, design: .default))
        .foregroundColor(theme.textTertiary)
    }
  }
}

// MARK: - Small

struct PrayerTrackerSmallView: View {
  let entry: PrayerTrackerEntry
  private var t: SalahTheme { entry.theme }

  var body: some View {
    let s = TrackerState(entry)
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 6) {
        Image(systemName: s.count == 5 ? "checkmark.seal.fill" : "checklist")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(Color.brand(t))
          .widgetAccentable()
        Eyebrow(text: WL.t("tracker.eyebrow"), color: t.textSecondary)
      }
      Spacer(minLength: 6)
      CountLabel(count: s.count, theme: t, size: 44)
      Text(s.subtitle)
        .font(.caption.weight(.medium))
        .foregroundColor(t.textSecondary)
        .lineLimit(1)
      Spacer(minLength: 10)
      HStack(spacing: 4) {
        ForEach(allPrayers, id: \.id) { p in
          Capsule()
            .fill(
              s.isKaza(p.id) ? kazaAccent(t)
                : s.isDone(p.id) ? Color.brand(t) : t.fill)
            .frame(height: 6)
        }
      }
      .widgetAccentable()
      .accessibilityHidden(true)
    }
    .accessibilityElement(children: .combine)
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

// MARK: - Prayer Button (widget'tan işaretleme)

struct PrayerCircleView: View {
  let prayer: PrayerInfo
  let isDone: Bool
  let isAvailable: Bool
  let isKaza: Bool
  let theme: SalahTheme

  var body: some View {
    // Widget'ta allowsHitTesting dikkate alınmaz: işaretlenemeyen vakit düğme olarak hiç çizilmez,
    // dokunma widget'ın kendi bağlantısına (uygulama) düşer.
    if !isDone && isAvailable {
      if #available(iOS 17.0, *) {
        Button(intent: MarkPrayerIntent(prayerId: prayer.id)) {
          content
        }
        .buttonStyle(.plain)
      } else {
        Link(destination: URL(string: "salah://home")!) {
          content
        }
      }
    } else {
      content
    }
  }

  private var content: some View {
    let tint = isKaza ? kazaAccent(theme) : Color.brand(theme)
    return VStack(spacing: 6) {
      ZStack {
        if isDone {
          // Kılındı: dolu daire + onay (kaza: uyarı tonu)
          Circle().fill(tint)
          Image(systemName: isKaza ? "clock.arrow.circlepath" : "checkmark")
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(theme.isDark ? Color.black.opacity(0.85) : .white)
        } else if isAvailable {
          // Vakit girdi, kılınmadı: dokunmaya davet eden halka
          // (uygulamadaki gibi altın halka)
          Circle().fill(Color.gold(theme).opacity(theme.isDark ? 0.14 : 0.10))
          Circle().strokeBorder(Color.gold(theme), lineWidth: 1.6)
          Image(systemName: prayerIcon(prayer.id))
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color.gold(theme))
        } else {
          // Vakit girmedi: pasif
          Circle().fill(theme.fill)
          Image(systemName: prayerIcon(prayer.id))
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(theme.textTertiary)
        }
      }
      .frame(width: 44, height: 44)
      .widgetAccentable()

      Text(prayer.label)
        .font(.system(.caption, design: .default, weight: isAvailable || isDone ? .semibold : .regular))
        .foregroundColor(isAvailable || isDone ? theme.textPrimary : theme.textTertiary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(prayer.label), \(statusText)")
    .accessibilityHint(!isDone && isAvailable ? WL.t("tracker.markHint") : "")
  }

  private var statusText: String {
    if isKaza { return WL.t("tracker.kaza") }
    if isDone { return WL.t("tracker.done") }
    return isAvailable ? WL.t("tracker.notDone") : WL.t("tracker.notYet")
  }
}

// MARK: - Medium

struct PrayerTrackerMediumView: View {
  let entry: PrayerTrackerEntry
  private var t: SalahTheme { entry.theme }

  var body: some View {
    let s = TrackerState(entry)
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Eyebrow(text: WL.t("tracker.title"), color: t.textSecondary)
          Text(s.subtitle)
            .font(.footnote.weight(.medium))
            .foregroundColor(s.count == 5 ? Color.brand(t) : t.textPrimary)
        }
        Spacer()
        CountLabel(count: s.count, theme: t, size: 30)
      }
      Spacer(minLength: 8)
      HStack(spacing: 0) {
        ForEach(allPrayers, id: \.id) { prayer in
          PrayerCircleView(
            prayer: prayer,
            isDone: s.isDone(prayer.id),
            isAvailable: isPrayerAvailable(prayer, widget: entry.widget, at: entry.date),
            isKaza: s.isKaza(prayer.id),
            theme: t
          )
          .frame(maxWidth: .infinity)
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

// MARK: - Entry View

struct PrayerTrackerWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: PrayerTrackerEntry

  var body: some View {
    switch family {
    case .systemSmall:
      PrayerTrackerSmallView(entry: entry)
    default:
      PrayerTrackerMediumView(entry: entry)
    }
  }
}

// MARK: - Lock Screen: Prayer Tracker

private let lockPrayerIDs = ["sabah", "ogle", "ikindi", "aksam", "yatsi"]

struct TrackerLockView: View {
  let entry: PrayerTrackerEntry
  @Environment(\.widgetFamily) var family

  private var completed: [String] { entry.tracker?.completedPrayers ?? [] }
  private var count: Int { lockPrayerIDs.filter { isPrayerCompleted($0, in: completed) }.count }
  private let total = 5

  var body: some View {
    if family == .accessoryCircular {
      circularBody
    } else {
      rectangularBody
    }
  }

  private var circularBody: some View {
    Gauge(value: Double(count), in: 0...Double(total)) {
      EmptyView()
    } currentValueLabel: {
      if count == total {
        Image(systemName: "checkmark")
          .font(.system(size: 20, weight: .bold))
      } else {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
          Text("\(count)")
            .font(.system(size: 20, weight: .semibold).monospacedDigit())
          Text("/\(total)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
      }
    }
    .gaugeStyle(.accessoryCircularCapacity)
    .widgetAccentable()
    .withAccessoryBackground()
  }

  private var rectangularBody: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 5) {
        Image(systemName: count == total ? "checkmark.seal.fill" : "checklist")
          .font(.system(size: 11, weight: .semibold))
          .widgetAccentable()
        Text(WL.t("tracker.title"))
          .font(.footnote.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .widgetAccentable()
        Spacer(minLength: 4)
        Text("\(count)/\(total)")
          .font(.footnote.weight(.semibold).monospacedDigit())
          .foregroundStyle(.secondary)
          .fixedSize()
      }
      prayerIconRow
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var prayerIconRow: some View {
    HStack(spacing: 0) {
      ForEach(lockPrayerIDs, id: \.self) { prayerId in
        slotIcon(for: prayerId)
          .frame(maxWidth: .infinity)
      }
    }
  }

  @ViewBuilder
  private func slotIcon(for id: String) -> some View {
    if isPrayerCompleted(id, in: completed) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 19, weight: .semibold))
        .widgetAccentable()
    } else {
      // Kılınmayan vakit kendi ikonuyla: hangisinin kaldığı bir bakışta görünür.
      Image(systemName: prayerIcon(id))
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(height: 22)
    }
  }
}

struct SalahTrackerLockWidget: Widget {
  let kind = "SalahTrackerLockWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PrayerTrackerProvider(theme: .dark)) { entry in
      TrackerLockView(entry: entry)
        .lockWidgetBackground()
        .widgetURL(URL(string: "salah://home"))
    }
    .configurationDisplayName(WL.t("tracker.title"))
    .description(WL.t("tracker.desc.small"))
    .supportedFamilies([.accessoryCircular, .accessoryRectangular])
  }
}

// MARK: - Widget Definitions

struct PrayerTrackerWidget: Widget {
  let kind = "SalahTrackerWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PrayerTrackerProvider(theme: .dark)) { entry in
      SystemThemed { theme in
        PrayerTrackerWidgetEntryView(
          entry: PrayerTrackerEntry(date: entry.date, tracker: entry.tracker, widget: entry.widget, theme: theme)
        )
        .premiumGated(isWidgetPremiumActive())
      }
      .widgetURL(URL(string: isWidgetPremiumActive() ? "salah://home" : "salah://paywall"))
    }
    .contentMarginsDisabled()
    .configurationDisplayName(WL.t("tracker.title"))
    .description(WL.t("tracker.desc.large"))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

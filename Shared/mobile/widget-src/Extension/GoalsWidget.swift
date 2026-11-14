import SwiftUI
import WidgetKit

// MARK: - Entry & Provider

struct GoalsEntry: TimelineEntry {
  let date: Date
  let snapshot: GoalsShared.Snapshot
  let theme: SalahTheme
}

struct GoalsProvider: TimelineProvider {
  private func entry(_ date: Date = Date()) -> GoalsEntry {
    GoalsEntry(date: date, snapshot: GoalsShared.current(GoalsShared.load() ?? .init(), now: date), theme: .dark)
  }
  func placeholder(in _: Context) -> GoalsEntry {
    GoalsEntry(date: Date(), snapshot: .init(kaza: 120, hifzDue: 5, hifzTotal: 40, teheccudToday: false, teheccudMonth: 6), theme: .dark)
  }
  func getSnapshot(in _: Context, completion: @escaping (GoalsEntry) -> Void) { completion(entry()) }
  /// Gece yarısı teheccüd işareti sıfırlansın diye ertesi gün başında yenilenir.
  func getTimeline(in _: Context, completion: @escaping (Timeline<GoalsEntry>) -> Void) {
    let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
    completion(Timeline(entries: [entry()], policy: .after(midnight)))
  }
}

// MARK: - Views

/// Tek hedef: simge, başlık, değer ve alt yazı; dokununca ilgili ekran.
private struct GoalTile: View {
  let icon: String
  let title: String
  let value: String
  let detail: String
  let url: String
  let theme: SalahTheme
  var highlight = false

  var body: some View {
    Link(destination: URL(string: url)!) {
      VStack(alignment: .leading, spacing: 3) {
        Image(systemName: icon).font(.system(size: 14, weight: .semibold))
          .foregroundColor(highlight ? Color.gold(theme) : Color.brand(theme)).widgetAccentable()
        Spacer(minLength: 0)
        Text(value).font(.system(size: 22, weight: .semibold)).monospacedDigit().foregroundColor(theme.textPrimary)
          .lineLimit(1).minimumScaleFactor(0.6)
        Text(title).font(.caption2.weight(.semibold)).foregroundColor(theme.textSecondary).lineLimit(1)
        Text(detail).font(.caption2).foregroundColor(theme.textTertiary).lineLimit(1).minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(10)
      .background(theme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .accessibilityElement(children: .combine)
  }
}

private func kazaTile(_ s: GoalsShared.Snapshot, _ t: SalahTheme) -> GoalTile? {
  guard let kaza = s.kaza else { return nil }
  return GoalTile(icon: "arrow.counterclockwise", title: WL.t("goalsW.kaza"), value: "\(kaza)", detail: WL.t("goalsW.kazaDetail"),
    url: "salah://kaza", theme: t)
}

private func hifzTile(_ s: GoalsShared.Snapshot, _ t: SalahTheme) -> GoalTile {
  GoalTile(icon: "graduationcap", title: WL.t("goalsW.hifz"), value: "\(s.hifzDue)",
    detail: s.hifzTotal == 0 ? WL.t("goalsW.hifzEmpty") : s.hifzDue == 0 ? WL.t("goalsW.hifzDone") : WL.t("goalsW.hifzDetail"),
    url: "salah://ezber", theme: t, highlight: s.hifzDue > 0)
}

private func teheccudTile(_ s: GoalsShared.Snapshot, _ t: SalahTheme) -> GoalTile? {
  guard let today = s.teheccudToday else { return nil }
  return GoalTile(icon: today ? "checkmark.circle.fill" : "moon.stars", title: WL.t("goalsW.teheccud"),
    value: today ? WL.t("goalsW.done") : WL.t("goalsW.notYet"), detail: WL.t("goalsW.month", String(s.teheccudMonth)),
    url: "salah://tracker/nafile", theme: t, highlight: today)
}

struct GoalsWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: GoalsEntry

  var body: some View {
    let s = entry.snapshot
    let t = entry.theme
    let tiles: [GoalTile] = [kazaTile(s, t), hifzTile(s, t), teheccudTile(s, t)].compactMap { $0 }
    VStack(alignment: .leading, spacing: 8) {
      Eyebrow(text: WL.t("goalsW.name"), color: t.textSecondary)
      if family == .systemSmall {
        VStack(spacing: 6) { ForEach(Array(tiles.prefix(2).enumerated()), id: \.offset) { _, tile in tile } }
      } else {
        HStack(spacing: 8) { ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in tile } }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

struct GoalsWidget: Widget {
  let kind = "SalahGoalsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GoalsProvider()) { entry in
      SystemThemed { theme in
        GoalsWidgetEntryView(entry: GoalsEntry(date: entry.date, snapshot: entry.snapshot, theme: theme))
      }
      .widgetURL(URL(string: "salah://kaza"))
    }
    .contentMarginsDisabled()
    .configurationDisplayName(WL.t("goalsW.name"))
    .description(WL.t("goalsW.desc"))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

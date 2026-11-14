import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Intents (widget sürecinde çalışır, uygulamayı açmaz)

/// Ana ekrandan bir zikir sayar. Durum App Group'ta (`DhikrShared`); uygulama öne gelince okur.
@available(iOS 17.0, *)
struct DhikrTapIntent: AppIntent {
  static var title: LocalizedStringResource = "Count dhikr"
  static var isDiscoverable = false

  func perform() async throws -> some IntentResult {
    let state = DhikrShared.load() ?? DhikrShared.State()
    DhikrShared.save(DhikrShared.tap(state).0)
    return .result()
  }
}

@available(iOS 17.0, *)
struct DhikrUndoIntent: AppIntent {
  static var title: LocalizedStringResource = "Undo dhikr"
  static var isDiscoverable = false

  func perform() async throws -> some IntentResult {
    var s = DhikrShared.rolled(DhikrShared.load() ?? DhikrShared.State())
    if s.mode == "free", s.count > 0 {
      s.count -= 1
      s.today = max(0, s.today - 1)
    } else if s.mode != "free", !s.tesbihat.done, s.tesbihat.count > 0 {
      s.tesbihat.count -= 1
      s.today = max(0, s.today - 1)
    }
    DhikrShared.save(s)
    return .result()
  }
}

/// Tamamlanan tesbihatı baştan başlatır.
@available(iOS 17.0, *)
struct DhikrRestartIntent: AppIntent {
  static var title: LocalizedStringResource = "Restart tasbih"
  static var isDiscoverable = false

  func perform() async throws -> some IntentResult {
    var s = DhikrShared.load() ?? DhikrShared.State()
    if s.mode == "free" { s.count = 0 } else { s.tesbihat = DhikrShared.Tesbihat() }
    DhikrShared.save(s)
    return .result()
  }
}

// MARK: - Entry & Provider

struct DhikrEntry: TimelineEntry {
  let date: Date
  let state: DhikrShared.State
  let theme: SalahTheme
}

struct DhikrProvider: TimelineProvider {
  func placeholder(in _: Context) -> DhikrEntry { DhikrEntry(date: Date(), state: DhikrShared.State(), theme: .dark) }
  func getSnapshot(in _: Context, completion: @escaping (DhikrEntry) -> Void) {
    completion(DhikrEntry(date: Date(), state: DhikrShared.load() ?? DhikrShared.State(), theme: .dark))
  }
  /// Gece yarısı "bugün" sıfırlansın diye ertesi gün başında yenilenir.
  func getTimeline(in _: Context, completion: @escaping (Timeline<DhikrEntry>) -> Void) {
    let entry = DhikrEntry(date: Date(), state: DhikrShared.load() ?? DhikrShared.State(), theme: .dark)
    let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
    completion(Timeline(entries: [entry], policy: .after(midnight)))
  }
}

// MARK: - Views

private struct DhikrRing: View {
  let count: Int
  let target: Int
  let theme: SalahTheme
  let size: CGFloat
  let lineWidth: CGFloat

  var body: some View {
    let progress = target > 0 ? Double(count > 0 && count % target == 0 ? target : count % target) / Double(target) : 0
    ZStack {
      Circle().stroke(theme.fill, lineWidth: lineWidth)
      Circle().trim(from: 0, to: progress)
        .stroke(Color.brand(theme), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .widgetAccentable()
      VStack(spacing: 0) {
        Text("\(count)").font(.widgetHero(size * 0.3)).foregroundColor(theme.textPrimary)
          .contentTransition(.numericText())
        if target > 0 {
          Text("/\(target)").font(.system(size: size * 0.1, weight: .semibold)).foregroundColor(theme.textTertiary).monospacedDigit()
        }
      }
    }
    .frame(width: size, height: size)
  }
}

private func dhikrName(_ id: String) -> String { WL.t("dhikrW.\(id)") }

/// Tesbihat tamamlandı: yeniden başlat düğmesi.
@available(iOS 17.0, *)
private struct DhikrDoneView: View {
  let theme: SalahTheme
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill").font(.system(size: 30)).foregroundColor(Color.gold(theme)).widgetAccentable()
      Text(WL.t("dhikrW.done")).font(.system(.subheadline, weight: .semibold)).foregroundColor(theme.textPrimary).multilineTextAlignment(.center)
      Button(intent: DhikrRestartIntent()) {
        Text(WL.t("dhikrW.again")).font(.system(.caption, weight: .semibold)).foregroundColor(theme.textPrimary)
          .padding(.horizontal, 12).padding(.vertical, 6).background(theme.fill, in: Capsule())
      }.buttonStyle(.plain)
    }
  }
}

@available(iOS 17.0, *)
struct DhikrSmallView: View {
  let entry: DhikrEntry
  var body: some View {
    let t = entry.theme
    let c = entry.state.current
    let done = entry.state.mode != "free" && entry.state.tesbihat.done
    VStack(alignment: .leading, spacing: 6) {
      Eyebrow(text: entry.state.mode == "free" ? WL.t("dhikrW.eyebrow") : WL.t("dhikrW.tesbihat"), color: t.textSecondary)
      if done {
        DhikrDoneView(theme: t).frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Button(intent: DhikrTapIntent()) {
          VStack(spacing: 6) {
            DhikrRing(count: c.count, target: c.target, theme: t, size: 86, lineWidth: 7)
            Text(dhikrName(c.id)).font(.system(.caption, weight: .semibold)).foregroundColor(t.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WL.t("dhikrW.tapA11y", dhikrName(c.id), String(c.count)))
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

@available(iOS 17.0, *)
struct DhikrMediumView: View {
  let entry: DhikrEntry
  var body: some View {
    let t = entry.theme
    let c = entry.state.current
    let done = entry.state.mode != "free" && entry.state.tesbihat.done
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Eyebrow(text: entry.state.mode == "free" ? WL.t("dhikrW.eyebrow") : WL.t("dhikrW.tesbihat"), color: t.textSecondary)
        Text(DhikrShared.arabic[c.id] ?? "")
          .font(.custom("KFGQPCHAFSUthmanicScript-Regula", size: c.id == "tesbihatClosing" ? 15 : 24, relativeTo: .title2))
          .foregroundColor(t.textPrimary).lineLimit(3).minimumScaleFactor(0.6)
          .environment(\.layoutDirection, .rightToLeft)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(dhikrName(c.id)).font(.system(.subheadline, weight: .semibold)).foregroundColor(Color.brand(t)).lineLimit(1)
        Spacer(minLength: 0)
        HStack(spacing: 8) {
          Text(WL.t("dhikrW.today", String(entry.state.todayCount(entry.date))))
            .font(.caption.weight(.medium)).foregroundColor(t.textSecondary).monospacedDigit()
          Spacer(minLength: 0)
          if !done {
            Button(intent: DhikrUndoIntent()) {
              Image(systemName: "arrow.uturn.backward").font(.system(size: 13, weight: .semibold)).foregroundColor(t.textSecondary)
                .frame(width: 30, height: 30).background(t.fill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WL.t("dhikrW.undo"))
          }
        }
      }
      if done {
        DhikrDoneView(theme: t).frame(width: 120)
      } else {
        Button(intent: DhikrTapIntent()) {
          DhikrRing(count: c.count, target: c.target, theme: t, size: 116, lineWidth: 9)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WL.t("dhikrW.tapA11y", dhikrName(c.id), String(c.count)))
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// Kilit ekranı: halka ve sayı; dokununca sayar.
@available(iOS 17.0, *)
struct DhikrCircularView: View {
  let entry: DhikrEntry
  var body: some View {
    let c = entry.state.current
    Button(intent: DhikrTapIntent()) {
      Gauge(value: Double(c.target > 0 ? c.count % max(c.target, 1) : 0), in: 0...Double(max(c.target, 1))) {
        Text(dhikrName(c.id))
      } currentValueLabel: {
        Text("\(c.count)").monospacedDigit()
      }
      .gaugeStyle(.accessoryCircularCapacity)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(WL.t("dhikrW.tapA11y", dhikrName(c.id), String(c.count)))
  }
}

@available(iOS 17.0, *)
struct DhikrWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: DhikrEntry

  var body: some View {
    switch family {
    case .accessoryCircular: DhikrCircularView(entry: entry)
    case .systemMedium: DhikrMediumView(entry: entry)
    default: DhikrSmallView(entry: entry)
    }
  }
}

@available(iOS 17.0, *)
struct DhikrWidget: Widget {
  let kind = "SalahDhikrWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DhikrProvider()) { entry in
      SystemThemed { theme in
        DhikrWidgetEntryView(entry: DhikrEntry(date: entry.date, state: entry.state, theme: theme))
      }
      .widgetURL(URL(string: "salah://zikir"))
    }
    .contentMarginsDisabled()
    .configurationDisplayName(WL.t("dhikrW.name"))
    .description(WL.t("dhikrW.desc"))
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
  }
}

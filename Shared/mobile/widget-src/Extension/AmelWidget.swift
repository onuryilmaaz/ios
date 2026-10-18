import SwiftUI
import WidgetKit

// MARK: - Entry & Provider

struct AmelEntry: TimelineEntry {
  let date: Date
  let data: AmelData?
  let theme: SalahTheme
}

struct AmelProvider: TimelineProvider {
  let theme: SalahTheme

  func placeholder(in _: Context) -> AmelEntry { AmelEntry(date: Date(), data: nil, theme: theme) }
  func getSnapshot(in _: Context, completion: @escaping (AmelEntry) -> Void) {
    completion(AmelEntry(date: Date(), data: AmelData.load(), theme: theme))
  }
  func getTimeline(in _: Context, completion: @escaping (Timeline<AmelEntry>) -> Void) {
    let entry = AmelEntry(date: Date(), data: AmelData.load(), theme: theme)
    let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

// MARK: - Type Tile (dokununca ilgili kayıt ekranı açılır)

private struct AmelTile: View {
  let type: String
  let isActive: Bool
  let theme: SalahTheme

  var body: some View {
    let tint = amelAccent(type, theme)
    Link(destination: URL(string: "salah://tracker/\(type)")!) {
      VStack(spacing: 5) {
        ZStack {
          Circle().fill(isActive ? tint : theme.fill)
          Image(systemName: amelIcon(for: type))
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isActive ? (theme.isDark ? Color.black.opacity(0.85) : .white) : theme.textTertiary)
        }
        .frame(width: 34, height: 34)
        .widgetAccentable()
        Text(amelLabel(for: type))
          .font(.system(.caption2, design: .default, weight: isActive ? .semibold : .regular))
          .foregroundColor(isActive ? theme.textPrimary : theme.textTertiary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(amelLabel(for: type)), \(isActive ? WL.t("amelW.logged") : WL.t("amelW.notLogged"))")
    }
  }
}

// MARK: - Small

struct AmelSmallView: View {
  let entry: AmelEntry
  private var t: SalahTheme { entry.theme }
  private var active: [String] { entry.data?.types ?? [] }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 6) {
        Image(systemName: "sparkles")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(Color.brand(t))
          .widgetAccentable()
        Eyebrow(text: WL.t("amelW.eyebrow"), color: t.textSecondary)
      }
      Spacer(minLength: 6)
      Text("\(entry.data?.totalCount ?? 0)")
        .font(.widgetHero(44))
        .foregroundColor(t.textPrimary)
        .widgetAccentable()
      Text(active.isEmpty ? WL.t("amelW.none") : WL.t("amelW.count", String(active.count)))
        .font(.caption.weight(.medium))
        .foregroundColor(t.textSecondary)
        .lineLimit(1)
      Spacer(minLength: 10)
      HStack(spacing: 4) {
        ForEach(allAmelTypes, id: \.self) { type in
          Capsule()
            .fill(active.contains(type) ? amelAccent(type, t) : t.fill)
            .frame(height: 6)
        }
      }
      .widgetAccentable()
    }
    .padding(15)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

// MARK: - Medium

struct AmelMediumView: View {
  let entry: AmelEntry
  private var t: SalahTheme { entry.theme }
  private var active: Set<String> { Set(entry.data?.types ?? []) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        Eyebrow(text: WL.t("amelW.title"), color: t.textSecondary)
        Spacer()
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text("\(active.count)")
            .font(.widgetHero(22))
            .foregroundColor(t.textPrimary)
          Text("/\(allAmelTypes.count)")
            .font(.system(.caption, design: .default, weight: .semibold))
            .foregroundColor(t.textTertiary)
        }
      }
      Spacer(minLength: 8)
      VStack(spacing: 8) {
        HStack(spacing: 0) {
          ForEach(allAmelTypes.prefix(4), id: \.self) { AmelTile(type: $0, isActive: active.contains($0), theme: t) }
        }
        HStack(spacing: 0) {
          ForEach(allAmelTypes.suffix(3), id: \.self) { AmelTile(type: $0, isActive: active.contains($0), theme: t) }
          Spacer().frame(maxWidth: .infinity)
        }
      }
    }
    .padding(15)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

// MARK: - Entry View

struct AmelWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: AmelEntry

  var body: some View {
    switch family {
    case .systemSmall:
      AmelSmallView(entry: entry)
    default:
      AmelMediumView(entry: entry)
    }
  }
}

// MARK: - Widget Definitions

struct AmelWidget: Widget {
  let kind = "SalahAmelWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: AmelProvider(theme: .dark)) { entry in
      SystemThemed { theme in
        AmelWidgetEntryView(entry: AmelEntry(date: entry.date, data: entry.data, theme: theme))
          .premiumGated(isWidgetPremiumActive())
      }
      .widgetURL(URL(string: isWidgetPremiumActive() ? "salah://home" : "salah://paywall"))
    }
    .configurationDisplayName(WL.t("amelW.name"))
    .description(WL.t("amelW.desc"))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

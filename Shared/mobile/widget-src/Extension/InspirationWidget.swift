import SwiftUI
import WidgetKit

struct InspirationEntry: TimelineEntry {
  let date: Date
  /// Ana ekran: uygulamanın o günkü içeriği (ayet ya da hadis), yoksa günün ayeti.
  let data: InspirationData?
  /// Kilit ekranı: yalnız ayet.
  let verse: InspirationData?
  let theme: SalahTheme

  static func make(at date: Date, app: InspirationData?, verses: [InspirationVerse], theme: SalahTheme)
    -> InspirationEntry
  {
    let day = dayKey(date)
    let verse = InspirationVerse.pick(for: day, in: verses)?.asInspiration
      ?? (app?.type == "ayet" ? app : nil)
    let todays = app?.date == day ? app : nil
    return InspirationEntry(date: date, data: todays ?? verse ?? app, verse: verse, theme: theme)
  }
}

struct InspirationProvider: TimelineProvider {
  let theme: SalahTheme

  func placeholder(in _: Context) -> InspirationEntry {
    InspirationEntry(date: Date(), data: nil, verse: nil, theme: theme)
  }
  func getSnapshot(in _: Context, completion: @escaping (InspirationEntry) -> Void) {
    completion(.make(at: Date(), app: InspirationData.loadRaw(), verses: InspirationVerse.loadAll(), theme: theme))
  }
  func getTimeline(in _: Context, completion: @escaping (Timeline<InspirationEntry>) -> Void) {
    let app = InspirationData.loadRaw()
    let verses = InspirationVerse.loadAll()
    let cal = Calendar.current
    let now = Date()
    // Şimdi + önümüzdeki 7 gece yarısı: gün dönümünde uygulama açılmadan yeni ayete geçer.
    var entries = [InspirationEntry.make(at: now, app: app, verses: verses, theme: theme)]
    var midnight = cal.startOfDay(for: now)
    for _ in 0..<7 {
      guard let next = cal.date(byAdding: .day, value: 1, to: midnight) else { break }
      midnight = next
      entries.append(.make(at: midnight, app: app, verses: verses, theme: theme))
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

// MARK: - Tip (ayet / hadis)

private struct InspirationStyle {
  let label: String
  let icon: String
  let tint: (SalahTheme) -> Color
}

private func styleForType(_ type: String) -> InspirationStyle {
  let lower = type.lowercased(with: Locale(identifier: "tr_TR"))
  if lower.contains("ayet") || lower.contains("verse") || lower.contains("quran") {
    return InspirationStyle(label: WL.t("insp.verse"), icon: "book.fill") { Color.gold($0) }
  }
  return InspirationStyle(label: WL.t("insp.hadith"), icon: "quote.opening") { Color.gold($0) }
}

private struct InspirationHeader: View {
  let style: InspirationStyle
  let theme: SalahTheme

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: style.icon)
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(style.tint(theme))
        .widgetAccentable()
      Eyebrow(text: style.label, color: theme.textSecondary)
      Spacer(minLength: 0)
    }
  }
}

private struct SourceLine: View {
  let source: String?
  let style: InspirationStyle
  let theme: SalahTheme
  var size: CGFloat = 11

  var body: some View {
    if let source, !source.isEmpty {
      HStack(spacing: 6) {
        Text(source)
          .font(.system(size: size, weight: .semibold))
          .foregroundColor(theme.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
  }
}

/// Okuma metni: uygulamadaki "Günün ayeti" kartıyla aynı sistem yazısı.
private func quoteFont(_ style: Font.TextStyle) -> Font {
  .system(style)
}

// MARK: - Small

struct InspirationSmallView: View {
  let entry: InspirationEntry
  private var t: SalahTheme { entry.theme }
  private var style: InspirationStyle { styleForType(entry.data?.type ?? "") }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      InspirationHeader(style: style, theme: t)
      Text(entry.data?.text ?? WL.t("insp.loading"))
        .font(quoteFont(.subheadline))
        .foregroundColor(t.textPrimary)
        .lineSpacing(2)
        .lineLimit(5)
        .minimumScaleFactor(0.8)
      Spacer(minLength: 0)
      SourceLine(source: entry.data?.source, style: style, theme: t, size: 10)
    }
    .padding(15)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Medium

struct InspirationMediumView: View {
  let entry: InspirationEntry
  private var t: SalahTheme { entry.theme }
  private var style: InspirationStyle { styleForType(entry.data?.type ?? "") }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      InspirationHeader(style: style, theme: t)
      Text(entry.data?.text ?? WL.t("insp.loading"))
        .font(quoteFont(.callout))
        .foregroundColor(t.textPrimary)
        .lineSpacing(3)
        .lineLimit(4)
        .minimumScaleFactor(0.85)
      Spacer(minLength: 0)
      SourceLine(source: entry.data?.source, style: style, theme: t)
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Large — Arapça orijinal + meal

struct InspirationLargeView: View {
  let entry: InspirationEntry
  private var t: SalahTheme { entry.theme }
  private var style: InspirationStyle { styleForType(entry.data?.type ?? "") }
  private var arabic: String {
    (entry.data?.arabic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      InspirationHeader(style: style, theme: t)
      Spacer(minLength: 0)

      if !arabic.isEmpty {
        Text(arabic)
          // Osmanlı imla işaretleri (ۡ ٗ) sistem fontunda harfleri koparıyor.
          .font(.custom("KFGQPCHAFSUthmanicScript-Regula", size: 24, relativeTo: .title2))
          .foregroundColor(t.textPrimary)
          .multilineTextAlignment(.trailing)
          .lineSpacing(6)
          .lineLimit(3)
          .minimumScaleFactor(0.7)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .environment(\.layoutDirection, .rightToLeft)
        Rectangle().fill(t.hairline).frame(height: 1)
      }

      Text(entry.data?.text ?? WL.t("insp.loading"))
        .font(quoteFont(.title3))
        .foregroundColor(t.textPrimary)
        .lineSpacing(5)
        .lineLimit(arabic.isEmpty ? 10 : 7)
        .minimumScaleFactor(0.8)

      Spacer(minLength: 0)
      SourceLine(source: entry.data?.source, style: style, theme: t, size: 12)
    }
    .padding(18)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Lock Screen (Accessory) Views — kilit ekranında yalnız ayet

@available(iOS 16.0, *)
struct InspirationAccessoryRectangularView: View {
  let entry: InspirationEntry
  private var style: InspirationStyle { styleForType("ayet") }

  var body: some View {
    // Kilit ekranı slotu sabit boyutlu; başlık satırını kaldırıp tüm alanı
    // ayet metnine ayırıyoruz. Tip ikonu satır başında kalır, metin
    // 4 satıra kadar açılır ve gerekirse ölçeklenir — böylece mümkün olan en
    // çok içerik görünür.
    HStack(alignment: .top, spacing: 5) {
      Image(systemName: style.icon)
        .font(.system(size: 11, weight: .bold))
      Text(entry.verse?.text ?? WL.t("insp.loading"))
        .font(.caption.weight(.medium))
        .lineLimit(4)
        .minimumScaleFactor(0.65)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetAccentable()
  }
}

@available(iOS 16.0, *)
struct InspirationAccessoryInlineView: View {
  let entry: InspirationEntry
  private var style: InspirationStyle { styleForType("ayet") }

  var body: some View {
    Label {
      Text(entry.verse?.text ?? WL.t("insp.fallback"))
        .lineLimit(1)
    } icon: {
      Image(systemName: style.icon)
    }
  }
}

@available(iOS 16.0, *)
struct InspirationAccessoryCircularView: View {
  let entry: InspirationEntry
  private var style: InspirationStyle { styleForType("ayet") }

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      Image(systemName: style.icon)
        .font(.system(size: 18, weight: .bold))
    }
    .widgetAccentable()
  }
}

// MARK: - Entry View

struct InspirationWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: InspirationEntry

  var body: some View {
    switch family {
    case .systemSmall:
      InspirationSmallView(entry: entry)
    case .systemLarge:
      InspirationLargeView(entry: entry)
    case .accessoryRectangular:
      if #available(iOS 16.0, *) { InspirationAccessoryRectangularView(entry: entry) }
    case .accessoryInline:
      if #available(iOS 16.0, *) { InspirationAccessoryInlineView(entry: entry) }
    case .accessoryCircular:
      if #available(iOS 16.0, *) { InspirationAccessoryCircularView(entry: entry) }
    default:
      InspirationMediumView(entry: entry)
    }
  }
}

// MARK: - Widget Definitions

struct InspirationWidget: Widget {
  let kind = "SalahInspirationWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: InspirationProvider(theme: .dark)) { entry in
      SystemThemed { theme in
        InspirationWidgetEntryView(
          entry: InspirationEntry(date: entry.date, data: entry.data, verse: entry.verse, theme: theme))
      }
      .widgetURL(URL(string: "salah://home"))
    }
    .configurationDisplayName(WL.t("insp.name"))
    .description(WL.t("insp.desc"))
    .supportedFamilies(inspirationSupportedFamilies())
  }
}

/// Home screen + (iOS 16'da) kilit ekranı accessory family'leri.
private func inspirationSupportedFamilies() -> [WidgetFamily] {
  var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
  if #available(iOS 16.0, *) {
    families.append(contentsOf: [.accessoryRectangular, .accessoryInline, .accessoryCircular])
  }
  return families
}

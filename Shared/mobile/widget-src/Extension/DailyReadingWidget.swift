import SwiftUI
import WidgetKit

// MARK: - Veri
//
// Uygulama önümüzdeki 7 günün "Günün okuması" içeriğini (meal dahil) App Group'a yazar (`salah_daily_reading`);
// widget ağa çıkmaz, gece yarısı kendi zaman çizelgesinden o günün içeriğine geçer.

struct DailyReadingDay: Codable {
  struct Esma: Codable { var arabic: String; var name: String; var meaning: String }
  struct Verse: Codable { var text: String; var source: String; var arabic: String? }
  struct Dua: Codable { var title: String; var text: String }
  var date: String
  var esma: Esma?
  var verse: Verse?
  var dua: Dua?

  private struct Payload: Codable { var days: [DailyReadingDay] }

  /// O günün içeriği; yoksa (uygulama 7 gündür açılmadı) nil: eski gün gösterilmez, uygulama içeriğiyle aynı kalır.
  static func load(for day: String) -> DailyReadingDay? {
    guard
      let ud = UserDefaults(suiteName: appGroupID),
      let data = ud.data(forKey: "salah_daily_reading"),
      let payload = try? JSONDecoder().decode(Payload.self, from: data)
    else { return nil }
    return payload.days.first { $0.date == day }
  }
}

struct DailyReadingEntry: TimelineEntry {
  let date: Date
  let day: DailyReadingDay?
  let theme: SalahTheme

  static func gallerySample(theme: SalahTheme) -> DailyReadingEntry {
    let sample = DailyReadingDay(
      date: dayKey(Date()),
      esma: .init(arabic: "اَلرَّحْمٰنُ", name: "Er-Rahmân", meaning: ""),
      verse: .init(text: WL.t("insp.fallback"), source: "", arabic: nil),
      dua: nil)
    return DailyReadingEntry(date: Date(), day: sample, theme: theme)
  }
}

struct DailyReadingProvider: TimelineProvider {
  let theme: SalahTheme

  func placeholder(in _: Context) -> DailyReadingEntry { .gallerySample(theme: theme) }
  func getSnapshot(in context: Context, completion: @escaping (DailyReadingEntry) -> Void) {
    if context.isPreview { return completion(.gallerySample(theme: theme)) }
    completion(DailyReadingEntry(date: Date(), day: DailyReadingDay.load(for: dayKey(Date())), theme: theme))
  }
  func getTimeline(in _: Context, completion: @escaping (Timeline<DailyReadingEntry>) -> Void) {
    let cal = Calendar.current
    let now = Date()
    // Şimdi + önümüzdeki 7 gece yarısı: gün dönümünde uygulama açılmadan yeni içeriğe geçer.
    var entries = [DailyReadingEntry(date: now, day: DailyReadingDay.load(for: dayKey(now)), theme: theme)]
    var midnight = cal.startOfDay(for: now)
    for _ in 0..<7 {
      guard let next = cal.date(byAdding: .day, value: 1, to: midnight) else { break }
      midnight = next
      entries.append(DailyReadingEntry(date: midnight, day: DailyReadingDay.load(for: dayKey(midnight)), theme: theme))
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

// MARK: - Görünümler

private struct DailyHeader: View {
  let label: String
  let icon: String
  let theme: SalahTheme

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(Color.gold(theme)).widgetAccentable()
      Eyebrow(text: label, color: theme.textSecondary)
      Spacer(minLength: 0)
    }
  }
}

private func readingSource(_ text: String, theme: SalahTheme, size: CGFloat = 11) -> some View {
  Text(text).font(.system(size: size, weight: .semibold)).foregroundColor(theme.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
}

/// Küçük: günün Esması.
struct DailyReadingSmallView: View {
  let entry: DailyReadingEntry
  private var t: SalahTheme { entry.theme }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      DailyHeader(label: WL.t("dr.esma"), icon: "sparkles", theme: t)
      if let esma = entry.day?.esma {
        Spacer(minLength: 0)
        Text(esma.arabic)
          .font(.system(size: 34, weight: .semibold))
          .foregroundColor(t.textPrimary)
          .lineLimit(1).minimumScaleFactor(0.5)
          .frame(maxWidth: .infinity, alignment: .center)
          .environment(\.layoutDirection, .rightToLeft)
        Text(esma.name).font(.system(size: 14, weight: .semibold)).foregroundColor(t.textPrimary)
          .lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, alignment: .center)
        if !esma.meaning.isEmpty {
          Text(esma.meaning).font(.system(size: 11)).foregroundColor(t.textSecondary).lineLimit(2).minimumScaleFactor(0.8)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity, alignment: .center)
        }
        Spacer(minLength: 0)
      } else {
        Spacer(minLength: 0)
        Text(WL.t("dr.empty")).font(.footnote).foregroundColor(t.textSecondary)
        Spacer(minLength: 0)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .combine)
  }
}

/// Orta: günün ayeti (seçili dildeki meal, kaynak "Sure adı ayet"); uzunsa kırpılır.
struct DailyReadingMediumView: View {
  let entry: DailyReadingEntry
  private var t: SalahTheme { entry.theme }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      DailyHeader(label: WL.t("insp.verse"), icon: "book.fill", theme: t)
      if let verse = entry.day?.verse {
        Text(verse.text).font(.callout).foregroundColor(t.textPrimary).lineSpacing(3).lineLimit(5).minimumScaleFactor(0.8).layoutPriority(1)
        Spacer(minLength: 0)
        readingSource(verse.source, theme: t)
      } else {
        Spacer(minLength: 0)
        Text(WL.t("dr.empty")).font(.footnote).foregroundColor(t.textSecondary)
        Spacer(minLength: 0)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .combine)
  }
}

/// Büyük: günün ayeti ve günün duası (başlık ve anlam).
struct DailyReadingLargeView: View {
  let entry: DailyReadingEntry
  private var t: SalahTheme { entry.theme }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DailyHeader(label: WL.t("insp.verse"), icon: "book.fill", theme: t)
      if let verse = entry.day?.verse {
        Text(verse.text).font(.callout).foregroundColor(t.textPrimary).lineSpacing(3).lineLimit(6).minimumScaleFactor(0.8).layoutPriority(1)
        readingSource(verse.source, theme: t, size: 12)
      } else {
        Text(WL.t("dr.empty")).font(.footnote).foregroundColor(t.textSecondary)
      }
      Rectangle().fill(t.hairline).frame(height: 1)
      DailyHeader(label: WL.t("dr.dua"), icon: "hands.sparkles.fill", theme: t)
      if let dua = entry.day?.dua {
        Text(dua.title).font(.system(size: 14, weight: .semibold)).foregroundColor(t.textPrimary).lineLimit(2)
        Text(dua.text).font(.footnote).foregroundColor(t.textPrimary).lineSpacing(2).lineLimit(5).minimumScaleFactor(0.8)
      }
      Spacer(minLength: 0)
    }
    .padding(18)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .combine)
  }
}

struct DailyReadingWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: DailyReadingEntry

  var body: some View {
    switch family {
    case .systemSmall: DailyReadingSmallView(entry: entry)
    case .systemLarge: DailyReadingLargeView(entry: entry)
    default: DailyReadingMediumView(entry: entry)
    }
  }
}

struct DailyReadingWidget: Widget {
  let kind = "SalahDailyReadingWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DailyReadingProvider(theme: .dark)) { entry in
      SystemThemed { theme in
        DailyReadingWidgetEntryView(entry: DailyReadingEntry(date: entry.date, day: entry.day, theme: theme))
          .galleryPlaceholderReadable()
      }
      .widgetURL(URL(string: "salah://gunun-okumasi"))
    }
    .contentMarginsDisabled()
    .configurationDisplayName(WL.t("dr.name"))
    .description(WL.t("dr.desc"))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
